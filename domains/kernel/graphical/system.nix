{
  config,
  lib,
  pkgs,
  store,
  ...
}:

let
  cfg = config.domains.kernel.graphical;
  inherit (store) hasWayland;
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
      extraPortals =
        with pkgs;
        [ xdg-desktop-portal-gtk ] ++ lib.optionals hasWayland [ xdg-desktop-portal-wlr ];
      config.common.default = "*";
    };

    environment.systemPackages = with pkgs; [
      xrandr
      xset
    ];
  };
}
