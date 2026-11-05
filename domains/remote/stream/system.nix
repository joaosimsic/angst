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

  capSysAdmin = true;
  sunshineBin =
    if capSysAdmin then "${config.security.wrapperDir}/sunshine" else "${pkgs.sunshine}/bin/sunshine";

  sunshineSettings = {
    capture = "kms";
    output_name = "DP-1";
    csrf_allowed_origins = "https://100.118.236.87:47990,https://nixos.tail97bc58.ts.net:47990";
  };
  sunshineConf = (pkgs.formats.keyValue { }).generate "sunshine.conf" sunshineSettings;

  sunshineCredsScript = pkgs.writeShellScript "angst-sunshine-creds" ''
    set -eu
    umask 0077
    creds=${lib.escapeShellArg sunshineCreds}
    if [ ! -f "$creds" ]; then
      echo "sunshine credentials are not ready at $creds; retrying" >&2
      exit 1
    fi
    user=$(${pkgs.gnused}/bin/sed -n '1p' "$creds")
    pass=$(${pkgs.gnused}/bin/sed -n '2p' "$creds")
    exec ${sunshineBin} --creds "$user" "$pass"
  '';

  sunshineStartScript = pkgs.writeShellScript "angst-sunshine-start" ''
    set -eu
    exec ${sunshineBin} ${sunshineConf}
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
          extraUpFlags = [ "--ssh" ];
          extraSetFlags = [ "--ssh" ];
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
            # Safe to start directly: the unit is skipped via
            # ConditionPathExists until the host secret exists.
            autoStart = true;
            openFirewall = false;
            inherit capSysAdmin;
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
              sunshine.unitConfig.ConditionPathExists = sunshineCreds;
              sunshine.serviceConfig = {
                ExecStartPre = lib.mkForce [ "${sunshineCredsScript}" ];
                ExecStart = lib.mkForce [ "${sunshineStartScript}" ];
              };
              sunshine-creds-restart = {
                description = "angst: start or restart sunshine after credential rotation";
                after = [ "sunshine.service" ];
                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = "${pkgs.systemd}/bin/systemctl --user restart sunshine.service";
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

              # Rotation: PathModified fires on credential rewrite. Restart
              # rather than try-restart so an inactive Sunshine is started
              # too; switches rewrite the secret while the service is down.
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

        system.activationScripts.angstTailscaleSet = lib.stringAfter [ "users" ] ''
          if ${config.systemd.package}/bin/systemctl is-active --quiet tailscaled.service; then
            echo "angst: applying Tailscale set flags"
            if ! ${config.systemd.package}/bin/systemctl start tailscaled-set.service; then
              echo "angst: failed to apply Tailscale set flags" >&2
            fi
          fi
        '';

        users.users.${userConfig.username}.extraGroups = [
          "input"
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
