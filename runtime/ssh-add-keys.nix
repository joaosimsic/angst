{
  mkScript,
  pkgs,
  lib,
  goAngst,
}:
{ keys }:
mkScript {
  name = "ssh-add-keys";
  runtimeInputs = [ pkgs.openssh ];
  text = ''
    exec ${goAngst}/bin/angst ssh-add-keys ${toString (map lib.escapeShellArg keys)}
  '';
}