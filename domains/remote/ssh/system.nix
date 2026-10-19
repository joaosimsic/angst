{
  config,
  lib,
  ssh,
  userConfig,
  flakeSelf,
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
          AllowAgentForwarding = false;

          MaxStartups = "100:30:200";
        };
      };
    })
    (lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = [
        "d ${homeDirectory}/.ssh 0700 ${userConfig.username} users -"
      ];

      systemd.services.angst-provision-ssh-key = {
        description = "angst: decrypt and install the shared scope SSH keys";
        wantedBy = [ "multi-user.target" ];
        before = [ "home-manager-${userConfig.username}.service" ];
        after = [
          "local-fs.target"
          "vm-age-key.service"
        ];

        unitConfig = {
          RequiresMountsFor = [ "${homeDirectory}/.config/age" ];
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          ReadOnlyPaths = [
            "${homeDirectory}/.config/age"
            "${flakeSelf}/secrets/ssh"
          ];
          ReadWritePaths = [ "${homeDirectory}/.ssh" ];
          NoNewPrivileges = true;
          UMask = "0077";
          RestrictAddressFamilies = [ "AF_UNIX" ];
          ExecStart =
            (runtime.ssh-key-provision {
              inherit (userConfig) username homeDirectory;
              secretsDir = "${flakeSelf}/secrets/ssh";
            }).bin;
          Environment = [
            "ANGST_AGE_KEY_FILE=${homeDirectory}/.config/age/keys.txt"
            "ANGST_WORK_AGE_KEY_FILE=${homeDirectory}/.config/age/work-keys.txt"
          ];
        };
      };
    })
  ];
}
