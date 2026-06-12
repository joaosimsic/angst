{ config, lib, pkgs, theme, ... }:

let
  cfg = config.capabilities.desktop;

  themesLib = import ../themes/default.nix { inherit lib; };
  themeColors = themesLib.get theme;
in
{
  options.capabilities.desktop = {
    enable = lib.mkEnableOption "Graphical desktop with X11 and i3";
  };

  config = lib.mkIf cfg.enable {
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

    services.xserver.windowManager.i3.enable = true;

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
  };
}
