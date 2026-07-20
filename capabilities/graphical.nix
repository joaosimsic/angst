{
  config,
  lib,
  pkgs,
  theme,
  themes,
  ...
}:

let
  cfg = config.capabilities.graphical;
in
{
  options.capabilities.graphical = {
    enable = lib.mkEnableOption "Graphical desktop with X11";
  };

  config = lib.mkIf cfg.enable (
    let
      themeColors = themes.get theme;
    in
    {
      services = {
        xserver = {
          enable = true;
          displayManager.lightdm = {
            enable = true;
            background = "#${themeColors.palette.background.base}";
            greeters.gtk = {
              enable = true;
              extraConfig = ''
                user-background = false
              '';
            };
          };
        };
        libinput.enable = true;
        dbus.enable = true;
      };

      xdg.portal = {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        config.common.default = "*";
      };

      environment.systemPackages = with pkgs; [
        xrandr
        xset
      ];
    }
  );
}
