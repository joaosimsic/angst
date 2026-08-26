{
  config,
  lib,
  theme,
  themesLib,
  ...
}:

let
  cfg = config.domains.display.lightdm;
in
{
  options.domains.display.lightdm = {
    enable = lib.mkEnableOption "LightDM GTK greeter";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.domains.system.graphical.enable;
        message = "domains.display.lightdm requires domains.system.graphical to be enabled";
      }
      {
        assertion = !config.domains.display.ly.enable;
        message = "Only one display manager can be enabled: display.lightdm or display.ly";
      }
    ];

    services.xserver.displayManager.lightdm = lib.mkIf config.domains.system.graphical.enable (
      let
        themeColors = themesLib.get theme;
      in
      {
        enable = true;
        background = "#${themeColors.palette.background.base}";
        greeters.gtk = {
          enable = true;
          extraConfig = ''
            user-background = false
          '';
        };
      }
    );
  };
}
