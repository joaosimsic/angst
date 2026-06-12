{ config, lib, ... }:

let
  cfg = config.domains.terminal.ghostty;
in
{
  config = lib.mkIf cfg.enable {
    domains.wm._i3.configLines = [
      "bindsym $mod+Return exec ghostty"
      "bindsym $mod+Shift+Return exec ghostty"
    ];
  };
}
