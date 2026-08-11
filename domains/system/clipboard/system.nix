{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.system.clipboard;
in
{
  options.domains.system.clipboard = {
    enable = lib.mkEnableOption "Clipboard tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      xclip
      xsel
    ];
  };
}
