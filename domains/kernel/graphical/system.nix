{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.kernel.graphical;
in
{
  options.domains.kernel.graphical = {
    enable = lib.mkEnableOption "Graphical desktop with X11";
  };

  config = lib.mkIf cfg.enable {
    services = {
      xserver.enable = true;
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
  };
}
