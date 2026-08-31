{
  config,
  lib,
  pkgs,
  store,
  ...
}:

let
  cfg = config.domains.kernel.clipboard;
  inherit (store) hasWayland hasX11;
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
