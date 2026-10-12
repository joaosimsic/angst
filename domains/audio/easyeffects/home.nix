{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.audio.easyeffects;
  preset = import ./preset.nix;

  defaultSinkScript = pkgs.writeShellScript "easyeffects-default-sink" ''
    for _ in {1..100}; do
      if ${pkgs.wireplumber}/bin/wpctl status 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qF 'Easy Effects Sink'; then
        ${pkgs.pipewire}/bin/pw-metadata -n default 0 default.audio.sink '{ "name": "easyeffects_sink" }'
        exit 0
      fi

      ${pkgs.coreutils}/bin/sleep 0.1
    done

    exit 1
  '';
in
{
  config = lib.mkIf cfg.enable {
    services.easyeffects = {
      enable = true;
      preset = {
        output = "angst";
      };
      extraPresets.angst.output = preset;
    };

    systemd.user.services.easyeffects = {
      Unit.X-Restart-Triggers = [
        (builtins.hashString "sha256" (builtins.toJSON preset))
      ];
      Service.Environment = [
        "QT_QPA_PLATFORMTHEME=kde"
        "QT_STYLE_OVERRIDE=breeze"
        "QT_PLUGIN_PATH=${config.home.profileDirectory}/${pkgs.qt6.qtbase.qtPluginPrefix}"
        "QML2_IMPORT_PATH=${config.home.profileDirectory}/${pkgs.qt6.qtbase.qtQmlPrefix}"
      ];
    };

    systemd.user.services.easyeffects-default-sink = {
      Unit = {
        Description = "Set Easy Effects Sink as the default output device";
        After = [ "easyeffects.service" ];
        PartOf = [ "easyeffects.service" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${defaultSinkScript}";
        RemainAfterExit = true;
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
