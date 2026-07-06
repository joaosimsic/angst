{
  config,
  lib,
  pkgs,
  theme,
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
      themesLib = import ../themes/default.nix { inherit lib; };
      themeColors = themesLib.get theme;
    in
    {
      services.xserver.enable = true;
      services.libinput.enable = true;

      services.xserver.displayManager.lightdm = {
        enable = true;
        background = "#${themeColors.BG}";
        greeters.gtk = {
          enable = true;
          extraConfig = ''
            user-background = false
          '';
        };
      };

      services.dbus.enable = true;

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
