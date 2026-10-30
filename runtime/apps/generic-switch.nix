{
  mkScript,
  pkgs,
}:
mkScript {
  name = "generic-switch";
  runtimeInputs = with pkgs; [
    coreutils
    git
    nix
    nixos-rebuild
    sudo
    util-linux
  ];
  text = builtins.readFile ./generic-switch.sh;
}
