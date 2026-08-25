{
  config,
  lib,
  pkgs,
  userConfig,
  ...
}:

let
  repoPath = ".config/angst";
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

  systemd.services.angst-repo-symlink = lib.mkIf config.angst.isQemuVm {
    description = "Ensure ~/.config/angst symlink to host 9p mount";
    wantedBy = [ "multi-user.target" ];
    before = [ "home-manager-${userConfig.username}.service" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RequiresMountsFor = hostAngstPath;
      ExecStart = "${pkgs.bash}/bin/bash -c 'if [ -d ${lib.escapeShellArg hostAngstPath} ]; then mkdir -p $(dirname ${lib.escapeShellArg repoPathLink}); chown ${lib.escapeShellArg userConfig.username}:users ${lib.escapeShellArg repoPathDir} 2>/dev/null || true; ln -sfn ${lib.escapeShellArg hostAngstPath} ${lib.escapeShellArg repoPathLink}; fi'";
    };
  };
}
