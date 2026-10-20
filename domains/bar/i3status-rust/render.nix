{ themesLib, themeName }:

let
  t = themesLib.get themeName;
  p = t.palette;
in
[
  {
    path = "domains/bar/i3status-rust/config/config.toml";
    text = ''
      [icons]
      icons = "material-nf"

      [theme]
      theme = "plain"
      [theme.overrides]
      idle_bg = "#${p.background.base}"
      idle_fg = "#${p.foreground.base}"
      separator_bg = "#${p.background.base}"
      separator_fg = "#${p.accent.base}"

      [[block]]
      block = "cpu"
      interval = 5
      format = " $icon $utilization "
      [block.theme_overrides]
      warning_fg = "#${t.ansi.warn}"
      warning_bg = "#${p.background.base}"
      critical_fg = "#${t.ansi.error}"
      critical_bg = "#${p.background.base}"

      [[block]]
      block = "memory"
      interval = 5
      format = " $icon $mem_used_percents.eng(w:2) "
      [block.theme_overrides]
      warning_fg = "#${t.ansi.warn}"
      warning_bg = "#${p.background.base}"
      critical_fg = "#${t.ansi.error}"
      critical_bg = "#${p.background.base}"

      [[block]]
      block = "custom"
      interval = 5
      json = true
      shell = "/bin/sh"
      format = " \U000F02CA $text "
      command = """
      used=$(df -B1 --output=used /boot /state /home 2>/dev/null | tail -n +2 | { s=0; while read -r u; do s=$((s + u)); done; echo $s; })
      total=$(df -B1 --output=size /boot /state /home 2>/dev/null | tail -n +2 | { s=0; while read -r x; do s=$((s + x)); done; echo $s; })
      if [ "$total" -le 0 ]; then
        printf '{"state":"Idle","text":"disk n/a"}\n'
        exit 0
      fi
      pct=$((used * 1000 / total))
      ug10=$((used * 10 / 1073741824))
      tg10=$((total * 10 / 1073741824))
      if [ "$pct" -ge 900 ]; then state=Critical
      elif [ "$pct" -ge 800 ]; then state=Warning
      else state=Idle
      fi
      text=$(printf '%d.%dG/%d.%dG (%d.%d%%)' $((ug10 / 10)) $((ug10 % 10)) $((tg10 / 10)) $((tg10 % 10)) $((pct / 10)) $((pct % 10)))
      printf '{"state":"%s","text":"%s"}\n' "$state" "$text"
      """
      [block.theme_overrides]
      warning_fg = "#${t.ansi.warn}"
      warning_bg = "#${p.background.base}"
      critical_fg = "#${t.ansi.error}"
      critical_bg = "#${p.background.base}"

      [[block]]
      block = "sound"
      driver = "pulseaudio"
      step_width = 5
      max_vol = 150
      show_volume_when_muted = true
      format = " $icon {$volume.eng(w:2)|} "
      [block.theme_overrides]
      warning_fg = "#${t.ansi.error}"
      warning_bg = "#${p.background.base}"
      [[block.click]]
      button = "left"
      cmd = "pavucontrol"

      [[block]]
      block = "custom"
      interval = 1
      json = true
      shell = "/bin/sh"
      if_command = "command -v i3-mouse-hide >/dev/null 2>&1"
      command = "i3-mouse-hide status"
      format = " $icon "
      [block.theme_overrides]
      good_fg = "#${t.ansi.success}"
      good_bg = "#${p.background.base}"
      critical_fg = "#${t.ansi.error}"
      critical_bg = "#${p.background.base}"
      [[block.click]]
      button = "left"
      cmd = "i3-mouse-hide toggle"
      update = true

      [[block]]
      block = "time"
      interval = 5
      format = " <span color='#${p.foreground.variant}'>$timestamp.datetime(f:'%Y-%m-%d %H:%M')</span> "
    '';
  }
]
