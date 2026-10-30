{
  mkScript,
  pkgs,
  self,
}:
{
  username,
}:
mkScript {
  name = "angst-ssh-deploy";
  runtimeInputs = [ pkgs.nix ];
  text = ''
    set -euo pipefail
    target="''${NIX_DEFAULT_TARGET_HOST:-${username}}"
    echo "==> Deploying home-manager to $target..."
    nix build ${self}#homeConfigurations.${username}.activationPackage --print-build-logs
    echo "==> Activating..."; ./result/activate
    echo "==> Cleaning old Nix store..."; nix-collect-garbage -d; nix store gc; echo "==> Done."
  '';
}
