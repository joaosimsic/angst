function pretty_key(k) {
  gsub(/\$mod/, "Mod", k)
  gsub(/question/, "?", k)
  gsub(/plus/, "Plus", k)
  gsub(/minus/, "Minus", k)
  gsub(/Return/, "Enter", k)
  gsub(/Escape/, "Esc", k)
  gsub(/space/, "Space", k)
  if (k == "Mod+Shift+slash") k = "Mod+?"
  return k
}

function pretty_action(a, s) {
  s = a
  sub(/^exec[[:space:]]+(--no-startup-id[[:space:]]+)?/, "", s)
  sub(/^env[[:space:]]+GDK_BACKEND=x11[[:space:]]+/, "", s)
  sub(/^GDK_BACKEND=x11[[:space:]]+/, "", s)
  if (s == "mode \"resize\"") return "enter resize mode"
  if (s == "mode \"default\"") return "leave resize mode"
  gsub(/i3-workspace-group[[:space:]]+inner-move[[:space:]]+/, "move window to inner ", s)
  gsub(/i3-workspace-group[[:space:]]+inner-swap.*/, "swap inner workspaces", s)
  gsub(/i3-workspace-group[[:space:]]+inner[[:space:]]+/, "go to inner workspace ", s)
  gsub(/i3-workspace-group[[:space:]]+switch[[:space:]]+/, "switch group ", s)
  gsub(/i3-workspace-group[[:space:]]+move[[:space:]]+/, "move window to group ", s)
  gsub(/i3-workspace-group[[:space:]]+urgent/, "jump to urgent", s)
  gsub(/i3-mouse-hide[[:space:]]+toggle/, "toggle mouse hide", s)
  gsub(/i3-hardware-menu/, "toggle hardware menu", s)
  gsub(/i3-cheatsheet[[:space:]]+toggle/, "toggle shortcuts overlay", s)
  gsub(/i3-audio-mute/, "toggle audio mute", s)
  gsub(/i3-lock/, "lock screen", s)
  sub(/^i3-nagbar.*/, "exit i3", s)
  gsub(/angst-screenshot-save[[:space:]]+fullscreen/, "screenshot: fullscreen", s)
  gsub(/angst-screenshot-copy[[:space:]]+region/, "screenshot: region", s)
  gsub(/angst-screenshot-save[[:space:]]+window/, "screenshot: window", s)
  gsub(/angst-notify[[:space:]]+dismiss-all/, "dismiss all notifications", s)
  gsub(/angst-notify[[:space:]]+dismiss/, "dismiss notification", s)
  gsub(/angst-notify[[:space:]]+history/, "notification history", s)
  gsub(/angst-ftp-status[[:space:]]+toggle/, "toggle ftp mount", s)
  gsub(/ghostty[[:space:]]+-e[[:space:]]+yazi/, "file manager", s)
  gsub(/ghostty/, "terminal", s)
  gsub(/rofi[[:space:]]+-show[[:space:]]+drun/, "app launcher", s)
  gsub(/playerctl[[:space:]]+play-pause/, "play/pause", s)
  gsub(/playerctl[[:space:]]+next/, "next track", s)
  gsub(/playerctl[[:space:]]+previous/, "previous track", s)
  gsub(/playerctl[[:space:]]+stop/, "stop", s)
  gsub(/wpctl[[:space:]]+set-volume[[:space:]]+-l[[:space:]]+1\.5[[:space:]]+@DEFAULT_AUDIO_SINK@[[:space:]]+5%\+/, "volume up", s)
  gsub(/wpctl[[:space:]]+set-volume[[:space:]]+@DEFAULT_AUDIO_SINK@[[:space:]]+5%-/, "volume down", s)
  gsub(/wpctl[[:space:]]+set-mute[[:space:]]+@DEFAULT_AUDIO_SOURCE@[[:space:]]+toggle/, "toggle mic mute", s)
  gsub(/^resize shrink width.*/, "shrink width", s)
  gsub(/^resize grow width.*/, "grow width", s)
  gsub(/^resize shrink height.*/, "shrink height", s)
  gsub(/^resize grow height.*/, "grow height", s)
  if (s == "kill") s = "close window"
  else if (s == "split h") s = "split horizontally"
  else if (s == "split v") s = "split vertically"
  else if (s == "fullscreen toggle") s = "toggle fullscreen"
  else if (s == "floating toggle") s = "toggle floating"
  else if (s == "sticky toggle") s = "toggle sticky"
  else if (s == "focus mode_toggle") s = "toggle focus parent/child"
  else if (s == "focus parent") s = "focus parent"
  else if (s == "reload") s = "reload config"
  else if (s == "restart") s = "restart i3"
  return s
}

function section_for(a, m) {
  if (m != "") return "RESIZE MODE (after Mod+R)"
  if (a ~ /i3-workspace-group/) return "WORKSPACES"
  if (a ~ /^(kill|focus|move|split|fullscreen|floating|sticky|mode)([[:space:]]|$)/) return "WINDOWS"
  if (a ~ /(reload|restart|i3-nagbar|i3-lock)/) return "SESSION"
  return "LAUNCH & FEATURES"
}

function prepend(sec, k, a,   i) {
  for (i = n[sec]; i >= 1; i--) {
    keys[sec, i + 1] = keys[sec, i]
    acts[sec, i + 1] = acts[sec, i]
  }
  keys[sec, 1] = k
  acts[sec, 1] = a
  n[sec]++
}

/^[[:space:]]*#/ { next }

/^[[:space:]]*mode[[:space:]]+"/ {
  m = $0
  sub(/^[[:space:]]*mode[[:space:]]+"/, "", m)
  sub(/".*/, "", m)
  mode = m
  next
}

/^[[:space:]]*}/ { mode = ""; next }

/^[[:space:]]*bindsym[[:space:]]/ {
  line = $0
  sub(/^[[:space:]]*bindsym[[:space:]]+/, "", line)
  while (line ~ /^--/) sub(/^--[^[:space:]]+[[:space:]]+/, "", line)
  key = line
  sub(/[[:space:]].*/, "", key)
  raw = line
  sub(/^[^[:space:]]+[[:space:]]*/, "", raw)
  if (mode == "" && key !~ /\$mod/) next

  k = pretty_key(key)
  a = pretty_action(raw)
  if (length(a) > 39) a = substr(a, 1, 38) "~"

  if (mode == "" && k ~ /^Mod\+[0-9]$/) { seen_inner = 1; next }
  if (mode == "" && k ~ /^Mod\+Shift\+[0-9]$/) { seen_inner_move = 1; next }
  if (mode == "" && k ~ /^Mod\+Control\+[0-9]$/) { seen_group = 1; next }
  if (mode == "" && k ~ /^Mod\+Control\+Shift\+[0-9]$/) { seen_group_move = 1; next }

  sec = section_for(raw, mode)
  n[sec]++
  keys[sec, n[sec]] = k
  acts[sec, n[sec]] = a
}

END {
  if (seen_inner_move) prepend("WORKSPACES", "Mod+Shift+1..0", "move window to inner 1..10")
  if (seen_inner) prepend("WORKSPACES", "Mod+1..0", "go to inner workspace 1..10")
  if (seen_group_move) prepend("WORKSPACES", "Mod+Control+Shift+1..0", "move window to group 1..10")
  if (seen_group) prepend("WORKSPACES", "Mod+Control+1..0", "switch group 1..10")

  order[1] = "WINDOWS"
  order[2] = "WORKSPACES"
  order[3] = "LAUNCH & FEATURES"
  order[4] = "SESSION"
  order[5] = "RESIZE MODE (after Mod+R)"

  print "${color0}i3 SHORTCUTS${color}   ${color1}Mod+? toggles this overlay${color}"
  print ""

  for (o = 1; o <= 5; o++) {
    sec = order[o]
    if (n[sec] == 0) continue
    print "${color0}" sec "${color}"
    for (i = 1; i <= n[sec]; i += 2) {
      left = sprintf("%-25s %-40s", keys[sec, i], acts[sec, i])
      if (i + 1 <= n[sec])
        printf "%s   %-25s %s\n", left, keys[sec, i + 1], acts[sec, i + 1]
      else
        print left
    }
    print ""
  }
}
