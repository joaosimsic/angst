{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.kernel.clipboard;
in
{
  options.domains.kernel.clipboard = {
    enable = lib.mkEnableOption "Clipboard tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      xclip
      xsel
      wl-clipboard
    ];
  };
}
