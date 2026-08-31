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
          # angst capture/screenshot — i3 adapter (store-gated, hasX11=${if hasX11 then "1" else "0"})
          bindsym Print exec --no-startup-id angst-screenshot-save fullscreen
          bindsym Shift+Print exec --no-startup-id angst-screenshot-copy region
          bindsym $mod+Shift+s exec --no-startup-id angst-screenshot-copy region
          bindsym $mod+Print exec --no-startup-id angst-screenshot-save window
        ''
      else
        ''
          # capture.screenshot disabled or !hasX11 — no bindings
        ''
    );

    xdg.configFile."i3/notifications.conf".text = lib.mkDefault (
      if shouldBindNotif then
        ''
          # angst notifications — i3 adapter (store-gated, hasNotifications=${if hasNotifications then "1" else "0"})
          bindsym $mod+Shift+n exec --no-startup-id angst-notify dismiss
          bindsym $mod+Shift+m exec --no-startup-id angst-notify dismiss-all
          bindsym $mod+Control+n exec --no-startup-id angst-notify history
        ''
      else
        ''
          # notifications disabled or !hasX11 — no bindings
        ''
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
