{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.kernel.cursor;
in
{
  config = lib.mkIf cfg.enable {
    home.pointerCursor = {
      enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
  };
}
