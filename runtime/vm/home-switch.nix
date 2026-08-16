{
  mkScript,
  pkgs,
  goAngst,
}:

mkScript {
  name = "vm-home-switch";
  runtimeInputs = with pkgs; [
    nix
    coreutils
  ];
  text = ''
    exec ${goAngst}/bin/angst vm home-switch "$@"
  '';
}