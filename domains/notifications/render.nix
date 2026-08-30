{
  lib,
  themesLib,
  themeName,
  ...
}:

let
  t = themesLib.get themeName;
  p = t.palette;
in
[
  {
    path = "domains/notifications/config/dunstrc";
    text = ''
      [global]
          width = 350
          height = 300
          offset = 20x20
          origin = top-right
          transparency = 0
          frame_width = 2
          frame_color = "#${p.accent.base}"
          separator_color = "#${p.accent.base}"
          font = JetBrainsMono Nerd Font 10
          background = "#${p.background.base}"
          foreground = "#${p.foreground.variant}"
          corner_radius = 6
          padding = 12
          horizontal_padding = 12

      [urgency_low]
          background = "#${p.background.variant}"
          foreground = "#${p.foreground.variant}"
          frame_color = "#${p.accent.base}"
          timeout = 5

      [urgency_normal]
          background = "#${p.background.base}"
          foreground = "#${p.foreground.variant}"
          frame_color = "#${p.accent.base}"
          timeout = 8

      [urgency_critical]
          background = "#${p.background.base}"
          foreground = "#${t.ansi.error}"
          frame_color = "#${t.ansi.error}"
          timeout = 0
    '';
  }
  {
    path = "domains/notifications/config/mako";
    text = ''
      background-color=#${p.background.base}
      text-color=#${p.foreground.variant}
      border-color=#${p.accent.base}
      border-size=2
      border-radius=6
      font=JetBrainsMono Nerd Font 10
      width=350
      height=300
      margin=20
      padding=12
      default-timeout=8000
      max-visible=5
      anchor=top-right
      icons=1

      [urgency=high]
      background-color=#${p.background.base}
      text-color=#${t.ansi.error}
      border-color=#${t.ansi.error}
      default-timeout=0
    '';
  }
]
