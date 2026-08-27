{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.system.cursor;
in
{
  config = lib.mkIf cfg.enable {
    gtk.enable = true;
    home.pointerCursor = {
      enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };
  };
}
