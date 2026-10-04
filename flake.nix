{
  description = "agent-switchboard development shell";

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
      # nixpkgs with rust-overlay applied, so the devShell and packages.swb
      # draw from the same rust-bin release.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (pkgsFor system));
      # R-C239: lab consumes `packages.<system>.swb` instead of building swb
      # with its own (older) nixpkgs rustc.
      packageSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      rustChannel = (builtins.fromTOML (builtins.readFile ./rust-toolchain.toml)).toolchain.channel;
      workspaceVersion = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).workspace.package.version;
    in
    {
      # Bazel (via bazelisk and .bazelversion) is the build authority. Cargo,
      # rustfmt and clippy here are diagnostic mirrors only. R-C255: they come
      # from the rust-overlay release rust-toolchain.toml pins (1.97.1, the
      # one packages.swb builds with), with that file's components, instead
      # of nixpkgs' older rustc.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            (rust-bin.fromRustupToolchainFile ./rust-toolchain.toml)
            bazelisk
            gh
            git
            gitleaks
            jq
            just
            python3
            rsync
            trufflehog
          ];
        };
      });

      # The swb binary built with the toolchain rust-toolchain.toml pins
      # (1.97.1, the same release MODULE.bazel registers for Bazel). Bazel
      # stays the build and test authority: `just check` runs the tests, so
      # this derivation only compiles the binary.
      packages = nixpkgs.lib.genAttrs packageSystems (
        system:
        let
          pkgs = pkgsFor system;
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
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
