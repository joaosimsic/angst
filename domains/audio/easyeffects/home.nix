{
  config,
  lib,
  pkgs,
  hostname,
  ...
}:

let
  cfg = config.domains.audio.easyeffects;
  preset = import ./preset.nix;

  presetJson = builtins.toJSON {
    output = preset;
  };

  nixPackage = pkgs.easyeffects;
in
{
  config = lib.mkIf cfg.enable (
    if hostname == "mint" then
      {
        xdg.configFile."easyeffects/output/angst.json".text = presetJson;

        xdg.configFile."autostart/easyeffects.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Easy Effects
          Comment=PipeWire audio effects
          Exec=easyeffects --gapplication-service --load-preset angst
          Terminal=false
          NoDisplay=true
          X-GNOME-Autostart-enabled=true
        '';
      }
    else
      {
        services.easyeffects = {
          enable = true;
          package = nixPackage;
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
      }
  );
}
