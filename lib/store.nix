{
  enabled,
  profiles ? [ ],
  editorLsp ? { },
}:

let
  domainId = e: if e.category == e.name then e.category else "${e.category}.${e.name}";
  names = map domainId enabled;
  has = n: builtins.elem n names;

  hasX11 = has "display.x11" || has "wm.i3" || has "display.lightdm" || has "display.ly";
  hasWayland = has "wm.hyprland" || has "display.wayland" || has "wm.sway";
  hasPortal = hasX11 || hasWayland || has "capture.screenshot";
  hasNotifications = has "notifications";
  isGraphical = has "kernel.graphical" || hasX11 || hasWayland;
  hasClipboard = has "kernel.clipboard";
  hasAudio = has "kernel.audio";
  hasPaper = has "design.paper";
  hasVm = builtins.elem "vm" profiles;
  hasLspmux = has "editor.lspmux";
in
{
  inherit
    hasX11
    hasWayland
    hasPortal
    hasNotifications
    isGraphical
    hasClipboard
    hasAudio
    hasPaper
    hasVm
    hasLspmux
    editorLsp
    ;
  enabledNames = names;
  isX11Only = hasX11 && !hasWayland;
  isWaylandOnly = hasWayland && !hasX11;
  isHybrid = hasX11 && hasWayland;
}
