{
  mkScript,
  pkgs,
}:
mkScript {
  name = "check";
  runtimeInputs = [ pkgs.nix ];
  text = ''
    set -euo pipefail
    ${pkgs.nix}/bin/nix flake check --print-build-logs
  '';
}
