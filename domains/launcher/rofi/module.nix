{ config, lib, ... }:

let
  cfg = config.domains.launcher.rofi;
in
{
  config = lib.mkIf cfg.enable {
    domains.wm._i3.configLines = [
      "bindsym $mod+space exec rofi -show drun"
    ];
  };
}
