{
  lib,
  userConfig,
  repoPath,
  ...
}:

let
  hostAngstPath = "/host${userConfig.homeDirectory}/${repoPath}";
  angstConfigLink = "/home/${userConfig.username}/.config/angst";
  configDir = builtins.dirOf angstConfigLink;
  repoPathLink = "/home/${userConfig.username}/${repoPath}";
  repoPathDir = builtins.dirOf repoPathLink;
  angstConfigSymlink = lib.stringAfter [ "users" ] ''
    if [ -d ${lib.escapeShellArg hostAngstPath} ]; then
      mkdir -p "$(dirname ${lib.escapeShellArg angstConfigLink})"
      chown ${userConfig.username}:users ${lib.escapeShellArg configDir} 2>/dev/null || true
      ln -sfn ${lib.escapeShellArg hostAngstPath} ${lib.escapeShellArg angstConfigLink}
    fi
  '';
  repoPathSymlink = lib.stringAfter [ "users" ] ''
    if [ -d ${lib.escapeShellArg hostAngstPath} ]; then
      mkdir -p "$(dirname ${lib.escapeShellArg repoPathLink})"
      chown ${userConfig.username}:users ${lib.escapeShellArg repoPathDir} 2>/dev/null || true
      ln -sfn ${lib.escapeShellArg hostAngstPath} ${lib.escapeShellArg repoPathLink}
    fi
  '';
in
{
  system.activationScripts.angstConfigSymlink = angstConfigSymlink;
  system.activationScripts.angstRepoPathSymlink = repoPathSymlink;

  virtualisation.vmVariant.system.activationScripts.angstConfigSymlink = angstConfigSymlink;
  virtualisation.vmVariant.system.activationScripts.angstRepoPathSymlink = repoPathSymlink;
}
