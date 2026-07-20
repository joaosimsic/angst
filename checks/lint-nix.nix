{ pkgs }:

let
  repoRoot = ../.;
in
pkgs.runCommand "lint-nix"
  {
    nativeBuildInputs = [
      pkgs.deadnix
      pkgs.statix
    ];
  }
  ''
    cd ${repoRoot}
    echo "==> Running deadnix..."
    deadnix ./ --fail
    echo "==> Running statix..."
    statix check .
    touch $out
  ''
