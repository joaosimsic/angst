{
  mkScript,
  pkgs,
  goAngst,
}:

mkScript {
  name = "vm-nixos-switch";
  runtimeInputs = with pkgs; [
    nix
    coreutils
  ];
  text = ''
    exec ${goAngst}/bin/angst vm nixos-switch "$@"
  '';
}