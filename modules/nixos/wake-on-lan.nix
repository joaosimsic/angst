{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.angst.wakeOnLan;
in
{
  options.angst.wakeOnLan = {
    enable = lib.mkEnableOption "persistent Wake-on-LAN via magic packet";
    mac = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "34:5a:60:a3:01:ec";
      description = "MAC address of the NIC that must stay armed for magic packets.";
    };
    interface = lib.mkOption {
      type = lib.types.str;
      default = "enp42s0";
      description = "Kernel interface name carrying the magic-packet NIC.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.mac != "";
            message = "angst.wakeOnLan.mac must be set when angst.wakeOnLan.enable is true";
          }
        ];

        # udev applies .link files without networkd; arms NIC at add time.
        systemd.network.links."10-${cfg.interface}-wol" = {
          matchConfig.MACAddress = cfg.mac;
          linkConfig.WakeOnLan = "magic";
        };

        # Re-arm after driver rebind / resume; scripted networking not involved.
        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="${cfg.mac}", RUN+="${pkgs.ethtool}/bin/ethtool -s $name wol g"
        '';
      }

      # NetworkManager owns the link at runtime and can clear WoL flags;
      # re-arm each time the connection comes up.
      {
        networking.networkmanager.dispatcherScripts = [
          {
            type = "basic";
            source = pkgs.writeShellScript "angst-wol-rearm" ''
              if [ "''${1:-}" = "${cfg.interface}" ] && [ "''${2:-}" = "up" ]; then
                ${pkgs.ethtool}/bin/ethtool -s "${cfg.interface}" wol g || true
              fi
            '';
          }
        ];
      }
    ]
  );
}
