# We need bats 1.12 for "on_failure" but no public nixpkgs release has > 1.11, so we pull down the 1.12 derivation from
# nixpkgs repo. We should remove this once bats 1.12 is in a public nixpkgs release.
# If updating, also bump BATS_VERSION in the windows job in `.github/workflows/test-release.yaml`
nixpkgs:
let
  batsLambda = import (builtins.fetchurl {
    # 43cfd42b4d8eadf2c2ee58fcfea17f930d4eae6f points to a bats 1.12 derivation
    url = "https://github.com/NixOS/nixpkgs/raw/43cfd42b4d8eadf2c2ee58fcfea17f930d4eae6f/pkgs/by-name/ba/bats/package.nix";
    sha256 = "0fw4hqbcqjgsmrrckrnlja5bskzr5mvqnr1fqqq1cn039wi5fpnc";
  });
in
  batsLambda (nixpkgs.lib.getAttrs [
    "resholve"
    "lib"
    "stdenv"
    "fetchFromGitHub"
    "bash"
    "coreutils"
    "gnugrep"
    "ncurses"
    "findutils"
    "hostname"
    "parallel"
    "flock"
    "procps"
    "bats"
    "lsof"
    "callPackages"
    "symlinkJoin"
    "makeWrapper"
    "runCommand"
    "bash-preexec"
    "kikit"
    "locate-dominating-file"
    "packcc"
  ] nixpkgs)
