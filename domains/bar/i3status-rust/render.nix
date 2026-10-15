{ themeSys, themeName }:

let
  t = themeSys.get themeName;
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
      block = "time"
      interval = 5
      format = " <span color='#${p.foreground.variant}'>$timestamp.datetime(f:'%Y-%m-%d %H:%M')</span> "
    '';
  }
]
