{
  config,
  lib,
  pkgs,
  userConfig,
  flakeSelf,
  ...
}:

let
  cfg = config.domains.remote.stream;

  tailscaleKeyAge = flakeSelf + "/secrets/apps/personal/tailscale-auth-key-nixos.age";
  hasTailscaleKey = builtins.pathExists tailscaleKeyAge;

  sunshineCreds = "${userConfig.homeDirectory}/.secrets/sunshine-credentials";

  sunshineCredsScript = pkgs.writeShellScript "angst-sunshine-credentials" ''
    set -eu
    umask 0077
    creds=${lib.escapeShellArg sunshineCreds}
    [ -f "$creds" ] || exit 0
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
        authKeyFile = "/run/angst/tailscale-auth-key";
      };
    };

    systemd = {
      user.services.sunshine.serviceConfig.ExecStartPre = [ "${sunshineCredsScript}" ];

      services = lib.mkIf hasTailscaleKey {
        angst-tailscale-auth-key = {
          description = "angst: decrypt the Tailscale auth key";
          wantedBy = [ "multi-user.target" ];
          before = [ "tailscaled-autoconnect.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            UMask = "0077";
            RuntimeDirectory = "angst";
            RuntimeDirectoryMode = "0700";
            ExecStart = "${pkgs.age}/bin/age --decrypt --identity ${userConfig.homeDirectory}/.config/age/keys.txt --output /run/angst/tailscale-auth-key ${tailscaleKeyAge}";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
            ReadOnlyPaths = [
              "${userConfig.homeDirectory}/.config/age/keys.txt"
              tailscaleKeyAge
            ];
          };
        };

        tailscaled-autoconnect = {
          after = [ "angst-tailscale-auth-key.service" ];
          wants = [ "angst-tailscale-auth-key.service" ];
        };
      };
    };

    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    hardware.graphics.enable = true;

    users.users.${userConfig.username}.extraGroups = [
      "uinput"
      "render"
    ];
  };
}
