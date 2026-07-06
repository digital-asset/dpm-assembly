{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }: {
    devShells = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        bats = import ./nix/bats.nix pkgs;

        shell = pkgs.mkShell {
          buildInputs = [
            pkgs.actionlint
            pkgs.bash
            pkgs.curl
            pkgs.gh
            pkgs.go-jsonnet
            pkgs.google-cloud-sdk
            pkgs.jdk
            pkgs.jq
            pkgs.maven
            pkgs.nodejs
            pkgs.oras
            pkgs.postgresql
            pkgs.yq-go
            pkgs.zip
            bats
          ];
        };
      in {
        default = shell;
        ci = shell;
      }
    );
  };
}
