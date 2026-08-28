{
  config,
  lib,
  store ? null,
  hostStore ? null,
  ...
}:

let
  cfg = config.domains.wm.i3;
  cap = config.domains.capture.screenshot or { enable = false; };
  effectiveStore = if store != null then store else hostStore;
  hasX11 = if effectiveStore != null then effectiveStore.hasX11 else true;
  shouldBind = cfg.enable && (cap.enable or false) && hasX11;
in
{
  config = lib.mkIf cfg.enable {
    xdg.configFile."i3/screenshot.conf".text = lib.mkDefault (
      if shouldBind then
        ''
          # angst capture/screenshot — i3 adapter (store-gated, hasX11=${if hasX11 then "1" else "0"})
          bindsym Print exec --no-startup-id angst-screenshot fullscreen
          bindsym Shift+Print exec --no-startup-id angst-screenshot region
          bindsym $mod+Shift+s exec --no-startup-id angst-screenshot region
          bindsym $mod+Print exec --no-startup-id angst-screenshot window
        ''
      else
        ''
          # capture.screenshot disabled or !hasX11 — no bindings
        ''
    );

    assertions = [
      {
        assertion = !shouldBind || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 screenshot bindings require domains.kernel.graphical to be enabled";
      }
    ];
  };
}
