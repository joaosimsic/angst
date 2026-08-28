{
  mkScript,
  pkgs,
  goVm,
 ...
}:

mkScript {
  name = "vm-home-switch";
  runtimeInputs = with pkgs; [
    nix
    coreutils
  ];
  text = ''
    exec ${goVm}/bin/vm home-switch "$@"
  '';
}
