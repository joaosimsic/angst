{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.bar.i3status;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.i3status ];
  };
}
