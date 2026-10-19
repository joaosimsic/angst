{
  mkScript,
  pkgs,
  self,
}:
{ system }:
mkScript {
  name = "lint-shell";
  runtimeInputs = [ pkgs.nix ];
  text = ''
    set -euo pipefail
    ${pkgs.nix}/bin/nix build ${self}#checks.${system}.lint-shell --no-link --print-build-logs
    echo "All shell config checks passed."
  '';
}
