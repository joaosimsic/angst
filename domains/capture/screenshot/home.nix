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
  effectiveBackend =
    if cfg.backend == "auto" then
      if hasWayland && !hasX11 then
        "grim"
      else if hasWayland && hasX11 then
        "portal"
      else
        "maim"
    else
      cfg.backend;
  angstScreenshot = runtime.capture-screenshot {
    backend = effectiveBackend;
    inherit (cfg)
      targetDir
      copyToClipboard
      saveToFile
      interactive
      ;
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
      default = "auto";
      description = "Capture backend. auto=detect $XDG_SESSION_TYPE/$WAYLAND_DISPLAY, portal=xdg-desktop-portal (X11+Wayland), maim=X11, grim=Wayland";
    };

    copyToClipboard = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Copy screenshot to clipboard (xclip/wl-copy)";
    };

    saveToFile = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Save screenshot to file";
    };

    targetDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/Pictures/Screenshots";
      description = "Directory to save screenshots (supports $HOME)";
    };

    interactive = lib.mkOption {
      type = lib.types.bool;
      default = false;
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

    home.packages = [ angstScreenshot ];
  };
}
