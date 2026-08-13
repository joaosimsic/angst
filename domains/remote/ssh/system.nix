{
  config,
  lib,
  ssh,
  userConfig,
  repoPath,
  runtime,
  ...
}:

let
  cfg = config.domains.remote.ssh;
  inherit (userConfig) homeDirectory;
in
{
  options.domains.remote.ssh = {
    enable = lib.mkEnableOption "SSH client, agent, and server";

    server = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = ssh.server.enable or false;
        description = "Run the SSH server (sshd) on this host";
      };
      passwordAuthentication = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow password authentication (disable for key-only)";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.server.enable) {
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = cfg.server.passwordAuthentication;
          PermitRootLogin = "no";
          AllowAgentForwarding = true;
        };
      };
    })
    (lib.mkIf cfg.enable {
      systemd.services.angst-provision-ssh-key = {
        description = "angst: decrypt and install the shared scope SSH keys";
        wantedBy = [ "multi-user.target" ];
        before = [ "home-manager-${userConfig.username}.service" ];
        after = [
          "local-fs.target"
          "vm-age-key.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          ReadWritePaths = [ "${homeDirectory}/.ssh" ];
          NoNewPrivileges = true;
          UMask = "0077";
          RestrictAddressFamilies = [ "AF_UNIX" ];
          ExecStart =
            (runtime.sshKeyProvision {
              inherit (userConfig) username homeDirectory;
              inherit repoPath;
            }).bin;
        };
      };
    })
  ];
}
