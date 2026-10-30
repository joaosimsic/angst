{
  config,
  lib,
  pkgs,
  userConfig,
  host,
  hostHostSecrets ? [ ],
  ...
}:

let
  cfg = config.domains.remote.stream;
  role = host.remoteStream.role;
  isHost = role == "host" || role == "both";

  hasTailscaleKey = lib.any (s: lib.hasSuffix "/tailscale" s) hostHostSecrets;

  sunshineCreds = "/run/angst/host-secrets/sunshine";

  sunshineCredsScript = pkgs.writeShellScript "angst-sunshine-credentials" ''
    set -eu
    umask 0077
    creds=${lib.escapeShellArg sunshineCreds}
    if [ ! -f "$creds" ]; then
      echo "sunshine credentials are not ready at $creds; retrying" >&2
      exit 1
    fi
    user=$(sed -n '1p' "$creds")
    pass=$(sed -n '2p' "$creds")
    exec ${pkgs.sunshine}/bin/sunshine --creds "$user" "$pass"
  '';
in
{
  options.domains.remote.stream = {
    enable = lib.mkEnableOption "Sunshine host and Moonlight client over Tailscale";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.tailscale = {
          enable = true;
          openFirewall = true;
        }
        // lib.optionalAttrs hasTailscaleKey {
          authKeyFile = "/run/angst/host-secrets/tailscale";
        };

        networking.firewall.trustedInterfaces = [ "tailscale0" ];

        hardware.graphics.enable = true;
      }
      (lib.mkIf isHost {
        services = {
          sunshine = {
            enable = true;
            # Started via systemd.user.paths.sunshine-creds once
            # /run/angst/host-secrets/sunshine exists. Direct WantedBy
            # would restart the user unit before the system
            # angst-provision-host-secrets.service creates the file on
            # first switch, failing activation with status 4.
            autoStart = false;
            openFirewall = false;
            capSysAdmin = false;
          };
          displayManager.defaultSession = "i3";
          displayManager.autoLogin = {
            enable = true;
            user = userConfig.username;
          };
        };

        systemd = {
          user = {
            services = {
              sunshine.serviceConfig.ExecStartPre = [ "${sunshineCredsScript}" ];
              sunshine-creds-restart = {
                description = "angst: restart sunshine after credential rotation";
                after = [ "sunshine.service" ];
                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = "${pkgs.systemd}/bin/systemctl --user try-restart sunshine.service";
                };
              };
            };

            paths = {
              # Event-driven start: path units never fail when the file is
              # missing, they wait. This covers first switch (host-secrets
              # service starts after user reload) and fresh boots.
              sunshine-creds = {
                wantedBy = [ "graphical-session.target" ];
                partOf = [ "graphical-session.target" ];
                pathConfig = {
                  PathExists = sunshineCreds;
                  Unit = "sunshine.service";
                };
              };

              # Rotation: PathModified fires on credential rewrite. Unit only
              # starts, never restarts, so fan out to a oneshot that
              # try-restarts (no-op when sunshine is not running).
              sunshine-creds-changed = {
                wantedBy = [ "graphical-session.target" ];
                partOf = [ "graphical-session.target" ];
                pathConfig = {
                  PathModified = sunshineCreds;
                  Unit = "sunshine-creds-restart.service";
                };
              };
            };
          };
        };

        users.users.${userConfig.username}.extraGroups = [
          "uinput"
          "render"
        ];

        assertions = [
          {
            assertion = config.domains.display.x11.enable;
            message = "domains.remote.stream role host requires domains.display.x11";
          }
          {
            assertion = config.domains.wm.i3.enable;
            message = "domains.remote.stream role host requires domains.wm.i3";
          }
          {
            assertion = config.domains.display.ly.enable;
            message = "domains.remote.stream role host requires domains.display.ly";
          }
          {
            assertion = lib.elem "i3" config.services.displayManager.sessionData.sessionNames;
            message = "domains.remote.stream role host requires the i3 display-manager session";
          }
        ];
      })
    ]
  );
}
