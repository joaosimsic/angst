{ config, lib, pkgs, ... }:

let
  cfg = config.capabilities.desktop;
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
      greeters.gtk.enable = true;
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
