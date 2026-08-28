{
  config,
  lib,
  pkgs,
  runtime,
  store ? null,
  hostStore ? null,
  ...
}:

let
  cfg = config.domains.capture.screenshot;
  effectiveStore = if store != null then store else hostStore;
  hasWayland = if effectiveStore != null then effectiveStore.hasWayland else false;
  hasX11 = if effectiveStore != null then effectiveStore.hasX11 else true;
  picturesDir = "$HOME/Pictures";
  captureBackend = "auto";
  captureInteractive = false;
  effectiveBackend =
    if captureBackend == "auto" then
      if hasWayland && !hasX11 then
        "grim"
      else if hasWayland && hasX11 then
        "portal"
      else
        "maim"
    else
      captureBackend;
  angstScreenshotSave = runtime.capture-screenshot {
    name = "angst-screenshot-save";
    backend = effectiveBackend;
    targetDir = picturesDir;
    copyToClipboard = false;
    saveToFile = true;
    interactive = captureInteractive;
  };
  angstScreenshotCopy = runtime.capture-screenshot {
    name = "angst-screenshot-copy";
    backend = effectiveBackend;
    targetDir = picturesDir;
    copyToClipboard = true;
    saveToFile = false;
    interactive = captureInteractive;
  };
in
{
  options.domains.capture.screenshot = {
    backend = lib.mkOption {
      type = lib.types.enum [
        "auto"
        "portal"
        "maim"
        "grim"
      ];
      description = "Capture backend. auto=detect $XDG_SESSION_TYPE/$WAYLAND_DISPLAY, portal=xdg-desktop-portal (X11+Wayland), maim=X11, grim=Wayland";
    };

    targetDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory to save screenshots (supports $HOME)";
    };

    interactive = lib.mkOption {
      type = lib.types.bool;
      description = "Use portal interactive dialog vs silent fullscreen";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.domains.kernel.graphical.enable;
        message = "domains.capture.screenshot requires domains.kernel.graphical to be enabled";
      }
    ];

    domains.capture.screenshot.backend = captureBackend;
    domains.capture.screenshot.targetDir = picturesDir;
    domains.capture.screenshot.interactive = captureInteractive;

    home.packages = [
      angstScreenshotSave
      angstScreenshotCopy
    ];
  };
}
