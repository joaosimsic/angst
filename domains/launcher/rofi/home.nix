{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.launcher.rofi;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.rofi ];
  };
}
