{
  mkScript,
  pkgs,
  goAngst,
}:
{ username }:
mkScript {
  name = "angst-vm-home-manager-upgrade";
  runtimeInputs = with pkgs; [
    systemd
  ];
  text = ''
    exec ${goAngst}/bin/angst vm home-manager-upgrade --user "${username}"
  '';
}