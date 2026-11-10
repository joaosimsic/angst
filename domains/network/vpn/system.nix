{
  config,
  lib,
  flakeSelf,
  runtime,
  userConfig,
  host,
  hostScopes ? [ ],
  ...
}:

let
  cfg = config.domains.network.vpn;

  servers = cfg.openvpn.servers // {
    cvx = {
      config = ''
        config /run/secrets/vpn/cvx.ovpn
        data-ciphers AES-256-CBC
        data-ciphers-fallback AES-256-CBC
        compat-mode 2.4.0
      '';
      authUserPass = "/run/secrets/vpn/cvx.creds";
      updateResolvConf = true;
      autoStart = host.toggles.workVpn or false;
    };
  };
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

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        boot.kernelModules = [ "tun" ];
        services.openvpn.servers = servers;

        security.polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (action.id == "org.freedesktop.systemd1.manage-units" &&
                subject.user == "${userConfig.username}" &&
                action.lookup("unit") == "openvpn-cvx.service" &&
                ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0) {
              return polkit.Result.YES;
            }
          });
        '';
      }

      (lib.mkIf (servers != { }) {
        systemd.services = {
          angst-provision-vpn = {
            description = "angst: decrypt VPN .ovpn + creds (declared scopes, ephemeral)";
            before = map (n: "openvpn-${n}.service") (builtins.attrNames servers);
            after = [
              "local-fs.target"
              "vm-age-key.service"
            ];
            wants = [ "network-online.target" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              PrivateTmp = true;
              ProtectSystem = "strict";
              ProtectHome = "read-only";
              ReadOnlyPaths = [
                "${userConfig.homeDirectory}/.config/age"
                "${flakeSelf}/${cfg.secretsDir}"
              ];
              ReadWritePaths = [ cfg.destDir ];
              NoNewPrivileges = true;
              UMask = "0077";
              RestrictAddressFamilies = [ "AF_UNIX" ];
              ExecStart =
                (runtime.vpn-provision {
                  secretsDir = "${flakeSelf}/${cfg.secretsDir}";
                  inherit (cfg) destDir;
                  inherit (userConfig) username homeDirectory;
                  scopes = hostScopes;
                }).bin;
            }
            // lib.optionalAttrs (lib.hasPrefix "/run/" cfg.destDir) {
              RuntimeDirectory = lib.removePrefix "/run/" cfg.destDir;
              RuntimeDirectoryMode = "0700";
            };
          };
        }
        // lib.genAttrs (map (n: "openvpn-${n}") (builtins.attrNames servers)) (_: {
          after = [ "angst-provision-vpn.service" ];
          requires = [ "angst-provision-vpn.service" ];
        });
      })
    ]
  );
}
