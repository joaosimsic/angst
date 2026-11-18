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

  package =
    if hostname == "mint" && config.lib ? nixGL then
      config.lib.nixGL.wrap pkgs.easyeffects
    else
      pkgs.easyeffects;
in
{
  config = lib.mkIf cfg.enable {
    services.easyeffects = {
      enable = true;
      inherit package;
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
