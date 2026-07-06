{
  lib,
  themesLib,
  themeName,
  fontFamily,
  monitors ? { },
  ...
}:

let
  t = themesLib.get themeName;

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
      # i3 config - colors from angst theme tokens

      font pango:${fontFamily} 10

      # Window borders
      default_border pixel 2
      default_floating_border pixel 2
      hide_edge_borders smart

      # Theme colors: border, background, text, indicator, child_border
      client.focused          #${t.INFO} #${t.BG} #${t.FG} #${t.INFO} #${t.INFO}
      client.focused_inactive #${t.MUTED} #${t.BG} #${t.SUBTLE} #${t.MUTED} #${t.MUTED}
      client.unfocused        #${t.BG} #${t.BG} #${t.SUBTLE} #${t.BG} #${t.BG}
      client.urgent           #${t.ERROR} #${t.BG} #${t.ERROR} #${t.WARNING} #${t.WARNING}

      set $mod Mod4

      include ~/.config/i3/monitors.conf

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

      bindsym $mod+1 workspace number 1
      bindsym $mod+2 workspace number 2
      bindsym $mod+3 workspace number 3
      bindsym $mod+4 workspace number 4
      bindsym $mod+5 workspace number 5
      bindsym $mod+6 workspace number 6
      bindsym $mod+7 workspace number 7
      bindsym $mod+8 workspace number 8
      bindsym $mod+9 workspace number 9
      bindsym $mod+0 workspace number 10

      bindsym $mod+Shift+1 move container to workspace number 1
      bindsym $mod+Shift+2 move container to workspace number 2
      bindsym $mod+Shift+3 move container to workspace number 3
      bindsym $mod+Shift+4 move container to workspace number 4
      bindsym $mod+Shift+5 move container to workspace number 5
      bindsym $mod+Shift+6 move container to workspace number 6
      bindsym $mod+Shift+7 move container to workspace number 7
      bindsym $mod+Shift+8 move container to workspace number 8
      bindsym $mod+Shift+9 move container to workspace number 9
      bindsym $mod+Shift+0 move container to workspace number 10

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
      exec_always --no-startup-id hsetroot -solid '#${t.BG}'
      exec --no-startup-id dbus-update-activation-environment --systemd --all
      exec --no-startup-id systemctl --user import-environment DISPLAY XAUTHORITY PATH XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS
      exec --no-startup-id systemctl --user start graphical-session.target
      bindsym $mod+space exec --no-startup-id rofi -show drun

      bar {
          status_command i3status -c ~/.config/i3status/config
          position top
          font pango:${fontFamily} 10
          colors {
              background #${t.BG}
              statusline #${t.FG}
              separator  #${t.SUBTLE}
              focused_workspace  #${t.BG} #${t.BG} #${t.FG}
              active_workspace   #${t.BG} #${t.BG} #${t.BRIGHT}
              inactive_workspace #${t.BG} #${t.BG} #${t.SUBTLE}
              urgent_workspace   #${t.ERROR} #${t.BG} #${t.FG}
          }
      }
    '';
  }
]
