{
  mkScript,
  pkgs,
  self,
 ...
}:
{ system }:
mkScript {
  name = "lint-desktop";
  runtimeInputs = [ pkgs.nix ];
  text = ''
    set -euo pipefail
    ${pkgs.nix}/bin/nix build ${self}#checks.${system}.lint-desktop --no-link --print-build-logs
    echo "All desktop config checks passed."
  '';
}
