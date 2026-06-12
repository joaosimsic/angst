{ config, lib, pkgs, ... }:

let
  cfg = config.domains.launcher.rofi;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.rofi ];

    domains.wm._i3.configLines = [
      "bindsym $mod+d exec rofi -show drun"
    ];
  };
}
