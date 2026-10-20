{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.audio.easyeffects;
  preset = import ./preset.nix;
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
  };
}
