{
  lib,
  userConfig,
  repoPath,
  ...
}:

let
  hostAngstPath = "/host${userConfig.homeDirectory}/${repoPath}";
  repoPathLink = "/home/${userConfig.username}/${repoPath}";
  repoPathDir = builtins.dirOf repoPathLink;
  repoPathSymlink = lib.stringAfter [ "users" ] ''
    if [ -d ${lib.escapeShellArg hostAngstPath} ]; then
      mkdir -p "$(dirname ${lib.escapeShellArg repoPathLink})"
      chown ${userConfig.username}:users ${lib.escapeShellArg repoPathDir} 2>/dev/null || true
      ln -sfn ${lib.escapeShellArg hostAngstPath} ${lib.escapeShellArg repoPathLink}
    fi
  '';
in
{
  system.activationScripts.angstRepoPathSymlink = repoPathSymlink;

  virtualisation.vmVariant.system.activationScripts.angstRepoPathSymlink = repoPathSymlink;
}
