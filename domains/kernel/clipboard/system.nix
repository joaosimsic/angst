{
  config,
  lib,
  pkgs,
  store ? null,
  hostStore ? null,
  ...
}:

let
  cfg = config.domains.kernel.clipboard;
  effectiveStore = if store != null then store else hostStore;
  hasWayland = if effectiveStore != null then effectiveStore.hasWayland else false;
  hasX11 = if effectiveStore != null then effectiveStore.hasX11 else true;
in
{
  options.domains.kernel.clipboard = {
    enable = lib.mkEnableOption "Clipboard tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      with pkgs;
      lib.optionals hasX11 [
        xclip
        xsel
      ]
      ++ lib.optionals hasWayland [ wl-clipboard ]
      ++ lib.optionals (!hasX11 && !hasWayland) [
        xclip
        wl-clipboard
      ];
  };
}
