{ lib, userConfig, ... }:

let
  hostAngstPath = "/host${userConfig.homeDirectory}/proj/angst";
  angstConfigLink = "/home/${userConfig.username}/.config/angst";
  configDir = builtins.dirOf angstConfigLink;
  angstConfigSymlink = lib.stringAfter [ "users" ] ''
    if [ -d ${lib.escapeShellArg hostAngstPath} ]; then
      mkdir -p "$(dirname ${lib.escapeShellArg angstConfigLink})"
      chown ${userConfig.username}:users ${lib.escapeShellArg configDir} 2>/dev/null || true
      ln -sfn ${lib.escapeShellArg hostAngstPath} ${lib.escapeShellArg angstConfigLink}
    fi
  '';
in
{
  system.activationScripts.angstConfigSymlink = angstConfigSymlink;

  virtualisation.vmVariant.system.activationScripts.angstConfigSymlink = angstConfigSymlink;
}
