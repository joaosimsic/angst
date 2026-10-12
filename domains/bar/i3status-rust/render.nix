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

      [[block]]
      block = "sound"
      driver = "pulseaudio"
      step_width = 5
      max_vol = 150
      show_volume_when_muted = true
      format = " $icon {$volume|} "
      [[block.click]]
      button = "left"
      cmd = "pavucontrol"
      [block.theme_overrides]
      idle_fg = "#${p.foreground.base}"
      warning_fg = "#${t.ansi.error}"
      warning_bg = "#${p.background.base}"

      [[block]]
      block = "time"
      interval = 5
      format = " <span color='#${p.foreground.variant}'>%Y-%m-%d %H:%M</span> "
    '';
  }
]
