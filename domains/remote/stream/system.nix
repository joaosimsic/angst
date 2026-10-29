{
  config,
  lib,
  pkgs,
  userConfig,
  hostHostSecrets ? [ ],
  ...
}:

let
  cfg = config.domains.remote.stream;

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

  config = lib.mkIf cfg.enable {
    services = {
      sunshine = {
        enable = true;
        autoStart = true;
        openFirewall = false;
        capSysAdmin = false;
      };

      tailscale = {
        enable = true;
        openFirewall = true;
      }
      // lib.optionalAttrs hasTailscaleKey {
        authKeyFile = "/run/angst/host-secrets/tailscale";
      };
    };

    systemd.user.services.sunshine.serviceConfig.ExecStartPre = [ "${sunshineCredsScript}" ];

    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    hardware.graphics.enable = true;

    users.users.${userConfig.username}.extraGroups = [
      "uinput"
      "render"
    ];
  };
}
