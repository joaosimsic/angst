{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.capabilities.ssh;
in
{
  options.capabilities.ssh = {
    enable = lib.mkEnableOption "SSH client and server";

    server = {
      enable = lib.mkEnableOption "SSH server (sshd)";
      passwordAuthentication = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow password authentication (disable for key-only)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      openssh
    ];

    services.openssh = lib.mkIf cfg.server.enable {
      enable = true;
      settings = {
        PasswordAuthentication = cfg.server.passwordAuthentication;
        PermitRootLogin = "no";
        AllowAgentForwarding = true;
      };
    };
  };
}
