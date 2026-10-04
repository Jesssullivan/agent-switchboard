{
  description = "agent-switchboard development shell and formal spec checks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Supplies the exact Rust release rust-toolchain.toml pins (nixpkgs
    # 26.05 ships 1.95, below the workspace rust-version).
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      # R-C239: lab consumes `packages.<system>.swb` instead of building swb
      # with its own (older) nixpkgs rustc.
      packageSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      rustChannel = (builtins.fromTOML (builtins.readFile ./rust-toolchain.toml)).toolchain.channel;
      workspaceVersion = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).workspace.package.version;

      # Formal spec (R-C229): Dhall types and records plus a Haskell
      # QuickCheck model. None of it is a Bazel or release input, and none of
      # it may be built on neo (teletype seat): run it on sting or honey.
      specDhallSource = nixpkgs.lib.fileset.toSource {
        root = ./.;
        fileset = nixpkgs.lib.fileset.unions [
          ./spec/dhall
          ./spec/fixtures
          ./spec/check-dhall.sh
          ./docs/releases/approved-broker.json
        ];
      };
      dhallTools = pkgs: [
        pkgs.dhall
        pkgs.dhall-json
        pkgs.jq
      ];
      # Written out by hand (what cabal2nix would emit) so evaluation needs no
      # import-from-derivation: `nix flake show` and `nix develop .#spec-dhall`
      # keep working on a seat that cannot build (neo has max-jobs = 0).
      # Keep the dependency lists in step with spec/haskell/swb-spec.cabal.
      swbSpec =
        pkgs:
        pkgs.haskellPackages.callPackage (
          {
            mkDerivation,
            aeson,
            base,
            bytestring,
            containers,
            http-client,
            http-types,
            QuickCheck,
            random,
            scientific,
            text,
            time,
            vector,
          }:
          mkDerivation {
            pname = "swb-spec";
            version = "0.1.0";
            src = ./spec/haskell;
            isLibrary = true;
            isExecutable = true;
            libraryHaskellDepends = [
              aeson
              base
              bytestring
              containers
              http-client
              http-types
              QuickCheck
              random
              scientific
              text
              time
              vector
            ];
            executableHaskellDepends = [
              aeson
              base
              containers
              http-client
              QuickCheck
            ];
            testHaskellDepends = [
              aeson
              base
              containers
              http-client
              QuickCheck
            ];
            preCheck = ''
              export SWB_SPEC_CONSTANTS=${./spec/dhall/generated/broker-constants.json}
            '';
            description = "Executable model and QuickCheck properties for agent-switchboard (R-C229)";
            license = "unknown";
            mainProgram = "swb-spec";
          }
        ) { };
    in
    {
      # Bazel (via bazelisk and .bazelversion) is the build authority. Cargo,
      # rustfmt and clippy here are diagnostic mirrors only.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            bazelisk
            cargo
            clippy
            gh
            git
            gitleaks
            jq
            just
            python3
            rsync
            rustc
            rustfmt
            trufflehog
          ];
        };
        # Interpreters only, no compilation: safe on any seat.
        spec-dhall = pkgs.mkShell { packages = dhallTools pkgs; };
        # GHC and cabal for working on spec/haskell. Build hosts only.
        spec = pkgs.mkShell {
          packages = dhallTools pkgs ++ [
            (pkgs.haskellPackages.ghcWithPackages (
              p: with p; [
                aeson
                http-client
                http-types
                QuickCheck
                random
                scientific
                text
                time
                vector
              ]
            ))
            pkgs.cabal-install
          ];
        };
      });


      apps = forAllSystems (pkgs: {
        # Run the same properties against a disposable broker on loopback:
        #   SWB_SPEC_BROKER_URL=http://127.0.0.1:18080 nix run .#spec-live
        spec-live = {
          type = "app";
          program = "${pkgs.writeShellScript "swb-spec-live" ''
            export SWB_SPEC_CONSTANTS="''${SWB_SPEC_CONSTANTS:-${./spec/dhall/generated/broker-constants.json}}"
            exec ${swbSpec pkgs}/bin/swb-spec "$@"
          ''}";
        };
      });

      checks = forAllSystems (pkgs: {
        spec-dhall = pkgs.runCommand "swb-spec-dhall" { nativeBuildInputs = dhallTools pkgs ++ [ pkgs.bash ]; } ''
          bash ${specDhallSource}/spec/check-dhall.sh ${specDhallSource}
          touch "$out"
        '';
        spec-quickcheck = swbSpec pkgs;
      });

      # The swb binary built with the toolchain rust-toolchain.toml pins
      # (1.97.1, the same release MODULE.bazel registers for Bazel). Bazel
      # stays the build and test authority: `just check` runs the tests, so
      # this derivation only compiles the binary. swb-spec (R-C229) is merged
      # in for every system; building it runs the model properties (cabal
      # test via doCheck).
      packages = nixpkgs.lib.recursiveUpdate (forAllSystems (pkgs: {
        swb-spec = swbSpec pkgs;
      })) (nixpkgs.lib.genAttrs packageSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };
          toolchain = pkgs.rust-bin.stable.${rustChannel}.minimal;
          rustPlatform = pkgs.makeRustPlatform {
            cargo = toolchain;
            rustc = toolchain;
          };
          swb = rustPlatform.buildRustPackage {
            pname = "swb";
            version = workspaceVersion;
            src = nixpkgs.lib.fileset.toSource {
              root = ./.;
              fileset = nixpkgs.lib.fileset.unions [
                ./Cargo.toml
                ./Cargo.lock
                ./crates
                ./schemas
              ];
            };
            cargoLock.lockFile = ./Cargo.lock;
            cargoBuildFlags = [
              "-p"
              "swb"
            ];
            doCheck = false;
            meta = {
              description = "agent-switchboard broker, agent daemon and hook client";
              mainProgram = "swb";
            };
          };
        in
        {
          inherit swb;
          default = swb;
        }
      ));

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
