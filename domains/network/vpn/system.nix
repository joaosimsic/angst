{
  config,
  lib,
  flakeSelf,
  runtime,
  userConfig,
  ...
}:

let
  cfg = config.domains.network.vpn;
in
{
  options.domains.network.vpn = {
    enable = lib.mkEnableOption "VPN connectivity via OpenVPN (age-encrypted secrets)";

    secretsDir = lib.mkOption {
      type = lib.types.str;
      default = "secrets/vpn";
      description = "Repo-relative directory containing age-encrypted VPN secrets (personal/work subdirs).";
    };

    destDir = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/vpn";
      description = "Runtime directory where decrypted .ovpn and .creds are provisioned (ephemeral, 0700).";
    };

    openvpn.servers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            config = lib.mkOption {
              type = lib.types.lines;
              description = "Configuration of this OpenVPN instance. Use 'config /run/secrets/vpn/<name>.ovpn' for age-encrypted configs.";
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
              description = "Automatically update resolv.conf with DNS information from OpenVPN (uses update-resolv-conf script).";
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
              description = ''
                Username/password credentials for the auth-user-pass method.
                Prefer a file path such as "/run/secrets/vpn/<name>.creds" decrypted from age.
                Using the {username; password;} attrset will put credentials WORLD-READABLE in the Nix store!
              '';
            };
          };
        }
      );
      default = { };
      description = "OpenVPN server/client instances (one systemd service per attribute).";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      boot.kernelModules = [ "tun" ];
      services.openvpn.servers = cfg.openvpn.servers;
    }

    (lib.mkIf (cfg.openvpn.servers != { }) {
      systemd.services = {
        angst-provision-vpn = {
          description = "angst: decrypt VPN .ovpn + creds (both scopes)";
          wantedBy = [ "multi-user.target" ];
          before = map (n: "openvpn-${n}.service") (builtins.attrNames cfg.openvpn.servers);
          after = [
            "local-fs.target"
            "vm-age-key.service"
          ];
          wants = [ "network-online.target" ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = (runtime.vpn-provision {
              secretsDir = "${flakeSelf}/${cfg.secretsDir}";
              inherit (cfg) destDir;
              inherit (userConfig) username homeDirectory;
              scopes = [
                "personal"
                "work"
              ];
            }).bin;
          };
        };
      }
      // lib.genAttrs (map (n: "openvpn-${n}") (builtins.attrNames cfg.openvpn.servers)) (_: {
        after = [ "angst-provision-vpn.service" ];
        requires = [ "angst-provision-vpn.service" ];
      });
    })
  ]);
}
