{
  description = "agent-switchboard development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
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
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
