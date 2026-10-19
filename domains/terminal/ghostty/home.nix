{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.terminal.ghostty;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.ghostty ];
  };
}
