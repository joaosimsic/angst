{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;
  p = t.palette;
in
[
  {
    path = "domains/bar/i3status/config/config";
    text = ''
      general {
          colors = true
          interval = 5
          markup = pango
          color_good = "#${t.ansi.success}"
          color_degraded = "#${t.ansi.warn}"
          color_bad = "#${t.ansi.error}"
      }

      order = "tztime local"

      tztime "local" {
          format = " <span color='#${p.foreground.variant}'>%Y-%m-%d %H:%M</span> "
      }
    '';
  }
]
