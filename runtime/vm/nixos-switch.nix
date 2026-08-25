{
  mkScript,
  pkgs,
  goVm,
}:

mkScript {
  name = "vm-nixos-switch";
  runtimeInputs = with pkgs; [
    nix
    coreutils
  ];
  text = ''
    exec ${goVm}/bin/vm nixos-switch "$@"
  '';
}
