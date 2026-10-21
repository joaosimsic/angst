{
  lib,
  themesLib,
  themeName,
  fontFamily,
  monitors ? { },
}:

let
  t = themesLib.get themeName;
  p = t.palette;

  monitorOrder = lib.unique (
    lib.filter (n: lib.hasAttr n monitors) (
      [
        "primary"
        "secondary"
      ]
      ++ lib.attrNames monitors
    )
  );

  monitorLine =
    name:
    let
      m = monitors.${name};
    in
    if m.resolution == "auto" then
      "exec --no-startup-id xrandr --output ${m.name} --auto --pos ${m.position}"
    else if m.resolution == "kernel" then
      "# ${m.name} resolution applied by the X session"
    else
      "exec --no-startup-id xrandr --output ${m.name} --mode ${m.resolution} --rate ${toString m.refreshRate} --pos ${m.position}";

  monitorsConf =
    if monitors == { } then
      "# no monitor overrides configured"
    else
      lib.concatStringsSep "\n" (map monitorLine monitorOrder);
in
[
  {
    path = "domains/wm/i3/config/monitors.conf";
    text = monitorsConf + "\n";
  }
  {
    path = "domains/wm/i3/config/config";
    text = ''


      font pango:${fontFamily} 10


      default_border pixel 0
      default_floating_border pixel 0
      hide_edge_borders smart

      client.focused          #${p.background.base} #${p.background.variant} #${p.foreground.base} #${p.background.base} #${p.background.base}
      client.focused_inactive #${p.background.base} #${p.background.base} #${p.dim} #${p.background.base} #${p.background.base}
      client.unfocused        #${p.background.base} #${p.background.base} #${p.dim} #${p.background.base} #${p.background.base}
      client.urgent           #${t.ansi.error} #${p.background.base} #${t.ansi.error} #${t.ansi.warn} #${t.ansi.warn}

      set $mod Mod4
      floating_modifier $mod
      tiling_drag modifier

      include ~/.config/i3/monitors.conf
      include ~/.config/i3/screenshot.conf
      include ~/.config/i3/screenshot.local.conf
      include ~/.config/i3/notifications.conf
      include ~/.config/i3/audio.conf
      include ~/.config/i3/media.conf

      bindsym $mod+q kill
      bindsym $mod+Shift+q kill

      bindsym $mod+h focus left
      bindsym $mod+j focus down
      bindsym $mod+k focus up
      bindsym $mod+l focus right

      bindsym $mod+Shift+h move left
      bindsym $mod+Shift+j move down
      bindsym $mod+Shift+k move up
      bindsym $mod+Shift+l move right

      bindsym $mod+v split h
      bindsym $mod+b split v
      bindsym $mod+f fullscreen toggle
      bindsym $mod+Shift+space floating toggle
      bindsym $mod+Tab focus mode_toggle
      bindsym $mod+a focus parent
      bindsym $mod+p exec --no-startup-id i3-mouse-hide toggle

      bindsym $mod+Control+1 exec --no-startup-id i3-workspace-group switch 1
      bindsym $mod+Control+2 exec --no-startup-id i3-workspace-group switch 2
      bindsym $mod+Control+3 exec --no-startup-id i3-workspace-group switch 3
      bindsym $mod+Control+4 exec --no-startup-id i3-workspace-group switch 4
      bindsym $mod+Control+5 exec --no-startup-id i3-workspace-group switch 5
      bindsym $mod+Control+6 exec --no-startup-id i3-workspace-group switch 6
      bindsym $mod+Control+7 exec --no-startup-id i3-workspace-group switch 7
      bindsym $mod+Control+8 exec --no-startup-id i3-workspace-group switch 8
      bindsym $mod+Control+9 exec --no-startup-id i3-workspace-group switch 9
      bindsym $mod+Control+0 exec --no-startup-id i3-workspace-group switch 10

      bindsym $mod+Control+Shift+1 exec --no-startup-id i3-workspace-group move 1
      bindsym $mod+Control+Shift+2 exec --no-startup-id i3-workspace-group move 2
      bindsym $mod+Control+Shift+3 exec --no-startup-id i3-workspace-group move 3
      bindsym $mod+Control+Shift+4 exec --no-startup-id i3-workspace-group move 4
      bindsym $mod+Control+Shift+5 exec --no-startup-id i3-workspace-group move 5
      bindsym $mod+Control+Shift+6 exec --no-startup-id i3-workspace-group move 6
      bindsym $mod+Control+Shift+7 exec --no-startup-id i3-workspace-group move 7
      bindsym $mod+Control+Shift+8 exec --no-startup-id i3-workspace-group move 8
      bindsym $mod+Control+Shift+9 exec --no-startup-id i3-workspace-group move 9
      bindsym $mod+Control+Shift+0 exec --no-startup-id i3-workspace-group move 10

      bindsym $mod+1 exec --no-startup-id i3-workspace-group inner 1
      bindsym $mod+2 exec --no-startup-id i3-workspace-group inner 2
      bindsym $mod+3 exec --no-startup-id i3-workspace-group inner 3
      bindsym $mod+4 exec --no-startup-id i3-workspace-group inner 4
      bindsym $mod+5 exec --no-startup-id i3-workspace-group inner 5
      bindsym $mod+6 exec --no-startup-id i3-workspace-group inner 6
      bindsym $mod+7 exec --no-startup-id i3-workspace-group inner 7
      bindsym $mod+8 exec --no-startup-id i3-workspace-group inner 8
      bindsym $mod+9 exec --no-startup-id i3-workspace-group inner 9
      bindsym $mod+0 exec --no-startup-id i3-workspace-group inner 10

      bindsym $mod+Shift+1 exec --no-startup-id i3-workspace-group inner-move 1
      bindsym $mod+Shift+2 exec --no-startup-id i3-workspace-group inner-move 2
      bindsym $mod+Shift+3 exec --no-startup-id i3-workspace-group inner-move 3
      bindsym $mod+Shift+4 exec --no-startup-id i3-workspace-group inner-move 4
      bindsym $mod+Shift+5 exec --no-startup-id i3-workspace-group inner-move 5
      bindsym $mod+Shift+6 exec --no-startup-id i3-workspace-group inner-move 6
      bindsym $mod+Shift+7 exec --no-startup-id i3-workspace-group inner-move 7
      bindsym $mod+Shift+8 exec --no-startup-id i3-workspace-group inner-move 8
      bindsym $mod+Shift+9 exec --no-startup-id i3-workspace-group inner-move 9
      bindsym $mod+Shift+0 exec --no-startup-id i3-workspace-group inner-move 10
      bindsym $mod+Shift+b exec --no-startup-id i3-workspace-group inner-swap 1 2

      bindsym $mod+Shift+c reload
      bindsym $mod+Shift+r restart
      bindsym $mod+Shift+e exec i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'

      mode "resize" {
          bindsym h resize shrink width 10 px or 10 ppt
          bindsym j resize grow height 10 px or 10 ppt
          bindsym k resize shrink height 10 px or 10 ppt
          bindsym l resize grow width 10 px or 10 ppt
          bindsym Return mode "default"
          bindsym Escape mode "default"
          bindsym $mod+r mode "default"
      }
      bindsym $mod+r mode "resize"

      for_window [class=".*"] title_format %title

      bindsym $mod+Return exec --no-startup-id GDK_BACKEND=x11 ghostty
      bindsym $mod+Shift+Return exec --no-startup-id GDK_BACKEND=x11 ghostty
      bindsym $mod+e exec --no-startup-id GDK_BACKEND=x11 ghostty -e yazi
      exec_always --no-startup-id env ANGST_INACTIVE_OPACITY=75 i3-workspace-group daemon
      exec_always --no-startup-id hsetroot -solid '#${p.background.base}'
      exec --no-startup-id dbus-update-activation-environment --systemd --all
      exec --no-startup-id systemctl --user import-environment DISPLAY XAUTHORITY PATH XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS
      exec --no-startup-id systemctl --user start graphical-session.target
      bindsym $mod+space exec --no-startup-id rofi -show drun

      bar {
          status_command i3status-rs ~/.config/i3status-rust/config.toml
          workspace_command i3-workspace-group bar ${t.ansi.error}
          position top
          font pango:${fontFamily} 10
          colors {
              background #${p.background.base}
              statusline #${p.foreground.base}
              separator  #${p.accent.base}
              focused_workspace  #${p.background.base} #${p.background.base} #${p.accent.base}
              active_workspace   #${p.background.base} #${p.background.base} #${p.foreground.base}
              inactive_workspace #${p.accent.base} #${p.accent.base} #${p.background.base}
              urgent_workspace   #${t.ansi.error} #${t.ansi.error} #${p.background.base}
          }
      }
    '';
  }
]
