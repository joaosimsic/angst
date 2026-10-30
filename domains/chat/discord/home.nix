{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.domains.chat.discord;
  voiceStatus = pkgs.callPackage ./voice-status.nix { };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ voiceStatus ];

    systemd.user.services.angst-discord-voice = {
      Unit = {
        Description = "Discord voice status for i3status-rust";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${voiceStatus}/bin/angst-discord-voice daemon";
        Restart = "on-failure";
        RestartSec = "2s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
