{
  mkScript,
  pkgs,
  goVm,
 ...
}:
{ username }:
mkScript {
  name = "angst-vm-home-manager-upgrade";
  runtimeInputs = with pkgs; [
    systemd
  ];
  text = ''
    exec ${goVm}/bin/vm home-manager-upgrade --user "${username}"
  '';
}
