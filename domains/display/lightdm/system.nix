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
        assertion = config.domains.kernel.graphical.enable;
        message = "domains.display.lightdm requires domains.kernel.graphical to be enabled";
      }
      {
        assertion = config.domains.display.x11.enable;
        message = "domains.display.lightdm requires domains.display.x11 to be enabled";
      }
      {
        assertion = !config.domains.display.ly.enable;
        message = "Only one display manager can be enabled: display.lightdm or display.ly";
      }
    ];

    services.xserver.displayManager.lightdm = lib.mkIf config.domains.kernel.graphical.enable (
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
            session=i3
          '';
        };
      }
    );
  };
}
