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
            autoStart = true;
            openFirewall = false;
            capSysAdmin = false;
          };
          displayManager.defaultSession = "i3";
          displayManager.autoLogin = {
            enable = true;
            user = userConfig.username;
          };
        };

        systemd.user.services.sunshine.serviceConfig.ExecStartPre = [ "${sunshineCredsScript}" ];

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
