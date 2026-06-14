{ config, lib, pkgs, ... }:

let
  cfg = config.domains.terminal.ghostty;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.ghostty ];

    domains.wm._i3.configLines = [
      "bindsym $mod+Return exec --no-startup-id GDK_BACKEND=x11 ${pkgs.ghostty}/bin/ghostty"
      "bindsym $mod+Shift+Return exec --no-startup-id GDK_BACKEND=x11 ${pkgs.ghostty}/bin/ghostty"
    ];
  };
}
