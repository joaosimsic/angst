{
  config,
  lib,
  ...
}:

let
  cfg = config.domains.notifications;
in
{
  options.domains.notifications = {
    enable = lib.mkEnableOption "Notification daemon (dunst/mako, X11/Wayland)";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.domains.kernel.graphical.enable;
        message = "domains.notifications requires domains.kernel.graphical to be enabled";
      }
    ];

    services.dbus.enable = true;
  };
}
