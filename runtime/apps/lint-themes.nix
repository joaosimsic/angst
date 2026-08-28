{
  mkScript,
  pkgs,
  self,
 ...
}:
mkScript {
  name = "lint-themes";
  runtimeInputs = [ pkgs.nix ];
  text = ''
    set -euo pipefail
    ${pkgs.nix}/bin/nix eval ${self}#lib.themeLint --raw
  '';
}
