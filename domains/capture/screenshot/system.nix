{
  config,
  lib,
  pkgs,
  store,
  ...
}:

let
  cfg = config.domains.capture.screenshot;
  inherit (store) hasWayland;
in
{
  options.domains.capture.screenshot = {
    enable = lib.mkEnableOption "Screen capture via xdg-desktop-portal (maim/grim/portal, i3 + hyprland)";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.domains.kernel.graphical.enable;
        message = "domains.capture.screenshot requires domains.kernel.graphical to be enabled";
      }
    ];

    services.dbus.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals =
        with pkgs;
        [ xdg-desktop-portal-gtk ] ++ lib.optionals hasWayland [ xdg-desktop-portal-wlr ];
      config.common.default = lib.mkDefault "*";
    };

    environment.systemPackages =
      with pkgs;
      [
        xdg-desktop-portal
        xdg-desktop-portal-gtk
      ]
      ++ lib.optionals hasWayland [ xdg-desktop-portal-wlr ];
  };
}
