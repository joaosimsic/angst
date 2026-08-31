{
  config,
  lib,
  store,
  ...
}:

let
  cfg = config.domains.wm.i3;
  cap = config.domains.capture.screenshot or { enable = false; };
  notif = config.domains.notifications or { enable = false; };
  inherit (store) hasX11 hasNotifications;
  shouldBind = cfg.enable && (cap.enable or false) && hasX11;
  shouldBindNotif = cfg.enable && (notif.enable or false) && hasX11 && hasNotifications;
in
{
  config = lib.mkIf cfg.enable {
    xdg.configFile."i3/screenshot.conf".text = lib.mkDefault (
      if shouldBind then
        ''
          bindsym Print exec --no-startup-id angst-screenshot-save fullscreen
          bindsym Shift+Print exec --no-startup-id angst-screenshot-copy region
          bindsym $mod+Shift+s exec --no-startup-id angst-screenshot-copy region
          bindsym $mod+Print exec --no-startup-id angst-screenshot-save window
        ''
      else
        ""
    );

    xdg.configFile."i3/notifications.conf".text = lib.mkDefault (
      if shouldBindNotif then
        ''
          bindsym $mod+Shift+n exec --no-startup-id angst-notify dismiss
          bindsym $mod+Shift+m exec --no-startup-id angst-notify dismiss-all
          bindsym $mod+Control+n exec --no-startup-id angst-notify history
        ''
      else
        ""
    );

    assertions = [
      {
        assertion = !shouldBind || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 screenshot bindings require domains.kernel.graphical to be enabled";
      }
      {
        assertion = !shouldBindNotif || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 notification bindings require domains.kernel.graphical to be enabled";
      }
    ];
  };
}
