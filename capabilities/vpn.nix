{
  config,
  lib,
  ...
}:

let
  cfg = config.capabilities.vpn;
in
{
  options.capabilities.vpn = {
    enable = lib.mkEnableOption "VPN connectivity";

    openvpn.servers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            config = lib.mkOption {
              type = lib.types.lines;
              description = "Configuration of this OpenVPN instance.";
            };

            up = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = "Shell commands executed when the instance is starting.";
            };

            down = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = "Shell commands executed when the instance is shutting down.";
            };

            autoStart = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether this OpenVPN instance should be started automatically.";
            };

            updateResolvConf = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Automatically update resolv.conf with DNS information from OpenVPN.";
            };

            authUserPass = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.oneOf [
                  lib.types.singleLineStr
                  (lib.types.submodule {
                    options = {
                      username = lib.mkOption {
                        type = lib.types.str;
                        description = "The username to store inside the credentials file.";
                      };
                      password = lib.mkOption {
                        type = lib.types.str;
                        description = "The password to store inside the credentials file.";
                      };
                    };
                  })
                ]
              );
              default = null;
              description = "Username/password credentials for the auth-user-pass method.";
            };
          };
        }
      );
      default = { };
      description = "OpenVPN server/client instances (one systemd service per attribute).";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "tun" ];
    services.openvpn.servers = cfg.openvpn.servers;
  };
}
