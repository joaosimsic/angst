{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.media.celluloid;

  videoMimes = [
    "video/mp4"
    "video/x-matroska"
    "video/webm"
    "video/quicktime"
    "video/x-msvideo"
    "video/mpeg"
    "video/ogg"
    "video/x-flv"
    "video/mp2t"
  ];

  desktopFile = "io.github.celluloid_player.Celluloid.desktop";
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.playerctl ];

    dconf.settings."io/github/celluloid-player/Celluloid" = {
      mpv-config-enable = true;
      mpv-config-file = "${config.home.homeDirectory}/.config/celluloid/mpv.conf";
    };

    xdg.mimeApps = {
      enable = true;
      defaultApplications = lib.genAttrs videoMimes (_: desktopFile);
      associations.added = lib.genAttrs videoMimes (_: desktopFile);
    };
  };
}
