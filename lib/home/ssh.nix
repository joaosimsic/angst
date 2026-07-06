{ lib, userConfig, ... }:

let
  gitSshHosts = userConfig.git.sshHosts or { };
  defaultIdentity = userConfig.ssh.identityFile or null;
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
      }
      // lib.optionalAttrs (defaultIdentity != null) {
        IdentityFile = defaultIdentity;
      };
    }
    // lib.mapAttrs (
      host: cfg:
      {
        Host = host;
        User = cfg.user or "git";
        StrictHostKeyChecking = cfg.strictHostKeyChecking or "accept-new";
      }
      // lib.optionalAttrs ((cfg.identityFile or defaultIdentity) != null) {
        IdentityFile = cfg.identityFile or defaultIdentity;
      }
    ) gitSshHosts;
  };
}
