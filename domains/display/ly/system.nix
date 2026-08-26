{
  config,
  lib,
  theme,
  themesLib,
  ...
}:

let
  cfg = config.domains.display.ly;
in
{
  options.domains.display.ly = {
    enable = lib.mkEnableOption "ly TUI display manager";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.domains.system.graphical.enable;
        message = "domains.display.ly requires domains.system.graphical to be enabled";
      }
      {
        assertion = !config.domains.display.lightdm.enable;
        message = "Only one display manager can be enabled: display.lightdm or display.ly";
      }
    ];

    services.displayManager.ly = lib.mkIf config.domains.system.graphical.enable (
      let
        themeColors = themesLib.get theme;
        p = themeColors.palette;
        hex = h: "0x00" + lib.removePrefix "#" h;
        hexBold = h: "0x01" + lib.removePrefix "#" h;
      in
      {
        enable = true;
        x11Support = true;
        settings = {
          bg = hex p.background.base;
          fg = hex p.foreground.base;
          border_fg = hex p.accent.base;
          error_bg = hex p.background.base;
          error_fg = hexBold themeColors.ansi.error;
        };
      }
    );
  };
}
