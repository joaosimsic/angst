{
  config,
  lib,
  ...
}:

let
  cfg = config.domains.wm.i3;
  cap = config.domains.capture.screenshot or { enable = false; };
  capEnabled = cap.enable or false;
in
{
  config = lib.mkIf cfg.enable {
    xdg.configFile."i3/screenshot.conf".text =
      if capEnabled then
        ''
          # angst capture/screenshot — i3 adapter (portal-abstracted, backend=${cap.backend or "auto"})
          # Fullscreen: Print, Region: Shift+Print, Window: Mod+Shift+s
          bindsym Print exec --no-startup-id angst-screenshot fullscreen
          bindsym Shift+Print exec --no-startup-id angst-screenshot region
          bindsym $mod+Shift+s exec --no-startup-id angst-screenshot region
          bindsym $mod+Print exec --no-startup-id angst-screenshot window
        ''
      else
        ''
          # capture.screenshot disabled — no bindings
        '';

    assertions = [
      {
        assertion = !capEnabled || config.domains.kernel.graphical.enable;
        message = "domains.wm.i3 screenshot bindings require domains.kernel.graphical to be enabled";
      }
    ];
  };
}
