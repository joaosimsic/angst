{
  config,
  lib,
  ssh,
  ...
}:

let
  cfg = config.domains.remote.ssh;
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

  config = lib.mkIf (cfg.enable && cfg.server.enable) {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = cfg.server.passwordAuthentication;
        PermitRootLogin = "no";
        AllowAgentForwarding = true;
      };
    };
  };
}
