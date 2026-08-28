{
  lib,
  enabled,
}:

let
  names = map (e: "${e.category}.${e.name}") enabled;
  has = n: builtins.elem n names;

  hasX11 = has "display.x11" || has "wm.i3" || has "display.lightdm" || has "display.ly";
  hasWayland = has "wm.hyprland" || has "display.wayland" || has "wm.sway";
  hasPortal = hasX11 || hasWayland || has "capture.screenshot";
  isGraphical = has "kernel.graphical" || hasX11 || hasWayland;
  hasClipboard = has "kernel.clipboard";
  hasAudio = has "kernel.audio";
in
{
  inherit hasX11 hasWayland hasPortal isGraphical hasClipboard hasAudio;
  enabledNames = names;
  isX11Only = hasX11 && !hasWayland;
  isWaylandOnly = hasWayland && !hasX11;
  isHybrid = hasX11 && hasWayland;
}
