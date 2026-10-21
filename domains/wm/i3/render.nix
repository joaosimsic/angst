{
  lib,
  themesLib,
  themeName,
  host,
  fontFamily,
  monitors ? { },
  homeDirectory,
}:

let
  t = themesLib.get themeName;
  p = t.palette;

  ftpBind = lib.optionalString ((host.ftp.mounts or [ ]) != [ ]) ''
    bindsym $mod+Shift+p exec --no-startup-id angst-ftp-status toggle
  '';

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
      bindsym $mod+Shift+f floating toggle
      bindsym $mod+Control+s sticky toggle
      bindsym $mod+Tab focus mode_toggle
      bindsym $mod+a focus parent
      bindsym $mod+p exec --no-startup-id i3-mouse-hide toggle
      ${ftpBind}
      bindsym $mod+u exec --no-startup-id i3-workspace-group urgent

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
      bindsym $mod+Escape exec --no-startup-id i3-lock

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
      for_window [class="^i3-hardware-menu$"] floating enable, border none, sticky enable
      for_window [class="^i3-cheatsheet$"] floating enable, border none, move to workspace current, move position center
      no_focus [class="^i3-cheatsheet$"]

      bindsym $mod+Return exec --no-startup-id GDK_BACKEND=x11 ghostty
      bindsym $mod+Shift+Return exec --no-startup-id GDK_BACKEND=x11 ghostty
      bindsym $mod+e exec --no-startup-id GDK_BACKEND=x11 ghostty -e yazi
      exec_always --no-startup-id env ANGST_INACTIVE_OPACITY=75 i3-workspace-group daemon
      exec_always --no-startup-id hsetroot -solid '#${p.background.base}'
      exec --no-startup-id dbus-update-activation-environment --systemd --all
      exec --no-startup-id systemctl --user import-environment DISPLAY XAUTHORITY PATH XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS
      exec --no-startup-id systemctl --user start graphical-session.target
      bindsym $mod+space exec --no-startup-id rofi -show drun
      bindsym --release $mod+i exec --no-startup-id i3-hardware-menu
      bindsym --release $mod+Shift+slash exec --no-startup-id i3-cheatsheet toggle

      bar {
          status_command i3status-rs ~/.config/i3status-rust/config.toml
          workspace_command i3-workspace-group bar ${t.ansi.error}
          position top
          tray_output none
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
  {
    path = "domains/wm/i3/config/hardware-menu.conky";
    text = ''
      conky.config = {
        alignment = 'top_right',
        gap_x = 20,
        gap_y = 42,
        xinerama_head = 0,
        minimum_width = 420,
        maximum_width = 420,
        own_window = true,
        own_window_type = 'normal',
        own_window_class = 'i3-hardware-menu',
        own_window_title = 'i3-hardware-menu',
        own_window_hints = 'undecorated,above,sticky,skip_taskbar,skip_pager',
        own_window_argb_visual = true,
        own_window_transparent = true,
        background = false,
        double_buffer = true,
        use_xft = true,
        override_utf8_locale = true,
        font = '${fontFamily}:size=10',
        update_interval = 1.0,
        total_run_times = 0,
        default_color = '#${p.foreground.base}',
        color0 = '#${p.accent.base}',
        color1 = '#${t.ansi.warn}',
        color2 = '#${t.ansi.error}',
        color3 = '#${t.ansi.success}',
        border_inner_margin = 12,
        border_outer_margin = 0,
        border_width = 0,
        draw_borders = false,
        draw_graph_borders = false,
        draw_shades = false,
        default_bar_height = 5,
        default_bar_width = 180,
        format_human_readable = true,
        short_units = true,
        pad_percents = 3,
        use_spacer = 'left',
        text_buffer_size = 512,
        lua_load = 'hardware-menu.lua',
        lua_draw_hook_pre = 'draw_bg',
      };

      conky.text = [[
      ''${color0}HARDWARE''${color}''${alignr}''${color0}''${time %H:%M:%S}''${color}
      ''${color0}''${hr 1}''${color}
      ''${color0}CPU''${color}''${goto 70}''${cpubar 5,180}''${goto 260}''${cpu}%''${goto 315}''${freq_g}GHz
      ''${color0}LOAD''${color}''${goto 315}''${loadavg}
      ''${color0}RAM''${color}''${goto 70}''${membar 5,180}''${goto 260}''${memperc}%''${goto 315}''${mem}/''${memmax}
      ''${color0}SWAP''${color}''${goto 70}''${swapbar 5,180}''${goto 260}''${swapperc}%''${goto 315}''${swap}/''${swapmax}
      ''${if_mounted /home}''${color0}HOME''${color}''${goto 70}''${fs_bar 5,180 /home}''${goto 260}''${fs_used_perc /home}%''${goto 315}''${fs_used /home}/''${fs_size /home}
      ''${endif}''${if_mounted /state}''${color0}STATE''${color}''${goto 70}''${fs_bar 5,180 /state}''${goto 260}''${fs_used_perc /state}%''${goto 315}''${fs_used /state}/''${fs_size /state}
      ''${endif}''${if_mounted /boot}''${color0}BOOT''${color}''${goto 70}''${fs_bar 5,180 /boot}''${goto 260}''${fs_used_perc /boot}%''${goto 315}''${fs_used /boot}/''${fs_size /boot}
      ''${endif}''${if_match "''${execi 2 i3-hardware-metrics --gpu-percent}" != "n/a"}''${color0}GPU''${color}''${goto 70}''${execibar 2 5,180 i3-hardware-metrics --gpu-percent}''${goto 260}''${execi 2 i3-hardware-metrics --gpu-percent-padded}%''${goto 315}''${execi 2 i3-hardware-metrics --gpu-mem}''${endif}
      ''${if_existing /sys/class/power_supply/BAT0}''${color0}BAT''${color}''${goto 70}''${battery_bar 5,180}''${goto 260}''${battery_percent}%''${goto 315}''${battery_time}
      ''${endif}''${color0}UP''${color}''${goto 315}''${uptime}
      ]];
    '';
  }
  {
    path = "domains/wm/i3/config/hardware-menu.lua";
    text = ''
      require("cairo")
      require("cairo_xlib")

      local base = "${p.background.base}"
      local accent = "${p.accent.base}"
      local warn = "${t.ansi.warn}"
      local crit = "${t.ansi.error}"

      local runtime = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
      local state_path = runtime .. "/i3-hardware-state"

      local function hex(c)
        return tonumber(c:sub(1, 2), 16) / 255,
               tonumber(c:sub(3, 4), 16) / 255,
               tonumber(c:sub(5, 6), 16) / 255
      end

      local function read_state()
        local f = io.open(state_path, "r")
        if not f then return "idle" end
        local line = f:read("*l") or ""
        f:close()
        local state, ts = line:match("^(%a+)%s+(%d+)$")
        if not state or not ts then return "idle" end
        if os.time() - tonumber(ts) > 15 then return "idle" end
        return state:lower()
      end

      function conky_draw_bg()
        if not conky_window then return end
        local w = conky_window.width or 420
        local h = conky_window.height or 240
        local surface = cairo_xlib_surface_create(
          conky_window.display,
          conky_window.drawable,
          conky_window.visual,
          w,
          h
        )
        local cr = cairo_create(surface)
        local state = read_state()
        local r, g, b = hex(base)
        cairo_set_source_rgba(cr, r, g, b, 1)
        cairo_rectangle(cr, 0, 0, w, h)
        cairo_fill(cr)
        local tr, tg, tb = hex(accent)
        if state == "warning" then
          tr, tg, tb = hex(warn)
        elseif state == "critical" then
          tr, tg, tb = hex(crit)
        end
        if state == "warning" or state == "critical" then
          cairo_set_source_rgba(cr, tr, tg, tb, 0.22)
          cairo_rectangle(cr, 0, 0, w, h)
          cairo_fill(cr)
        end
        cairo_set_source_rgba(cr, tr, tg, tb, 1)
        cairo_set_line_width(cr, 1)
        cairo_rectangle(cr, 0.5, 0.5, w - 1, h - 1)
        cairo_stroke(cr)
        cairo_destroy(cr)
        cairo_surface_destroy(surface)
      end
    '';
  }
  {
    path = "domains/wm/i3/config/cheatsheet.conky";
    text = ''
      conky.config = {
        alignment = 'middle_middle',
        gap_x = 0,
        gap_y = -12,
        xinerama_head = 0,
        minimum_width = 1060,
        maximum_width = 1060,
        own_window = true,
        own_window_type = 'normal',
        own_window_class = 'i3-cheatsheet',
        own_window_title = 'i3-cheatsheet',
        own_window_hints = 'undecorated,above,skip_taskbar,skip_pager',
        own_window_argb_visual = true,
        own_window_transparent = true,
        background = false,
        double_buffer = true,
        use_xft = true,
        override_utf8_locale = true,
        font = '${fontFamily}:size=10',
        update_interval = 1.0,
        total_run_times = 0,
        default_color = '#${p.foreground.base}',
        color0 = '#${p.accent.base}',
        color1 = '#${p.foreground.variant}',
        border_inner_margin = 16,
        border_outer_margin = 0,
        border_width = 0,
        draw_borders = false,
        draw_shades = false,
        draw_graph_borders = false,
        max_text_width = 0,
        text_buffer_size = 4096,
        max_user_text = 65536,
        lua_load = '${homeDirectory}/.config/i3/cheatsheet.lua',
        lua_draw_hook_pre = 'draw_bg',
      };

      conky.text = [[
      ''${execpi 1 cat ${homeDirectory}/.cache/i3-cheatsheet.txt}
      ]];
    '';
  }
  {
    path = "domains/wm/i3/config/cheatsheet.lua";
    text = ''
      require("cairo")
      require("cairo_xlib")

      local base = "${p.background.base}"
      local accent = "${p.accent.base}"

      local function hex(c)
        return tonumber(c:sub(1, 2), 16) / 255,
               tonumber(c:sub(3, 4), 16) / 255,
               tonumber(c:sub(5, 6), 16) / 255
      end

      function conky_draw_bg()
        if not conky_window then return end
        local w = conky_window.width or 1060
        local h = conky_window.height or 600
        local surface = cairo_xlib_surface_create(
          conky_window.display,
          conky_window.drawable,
          conky_window.visual,
          w,
          h
        )
        local cr = cairo_create(surface)
        local r, g, b = hex(base)
        cairo_set_source_rgba(cr, r, g, b, 1)
        cairo_rectangle(cr, 0, 0, w, h)
        cairo_fill(cr)
        local ar, ag, ab = hex(accent)
        cairo_set_source_rgba(cr, ar, ag, ab, 1)
        cairo_set_line_width(cr, 1)
        cairo_rectangle(cr, 0.5, 0.5, w - 1, h - 1)
        cairo_stroke(cr)
        cairo_rectangle(cr, 0, 0, w, 2)
        cairo_fill(cr)
        cairo_destroy(cr)
        cairo_surface_destroy(surface)
      end
    '';
  }
]
