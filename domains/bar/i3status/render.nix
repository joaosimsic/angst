{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;
in
[
  {
    path = "domains/bar/i3status/config/config";
    text = ''
      general {
          colors = true
          interval = 5
          markup = pango
          color_good = "#${t.SUCCESS}"
          color_degraded = "#${t.WARNING}"
          color_bad = "#${t.ERROR}"
      }

      order = "tztime local"

      tztime "local" {
          format = " <span color='#${t.BRIGHT}'>%Y-%m-%d %H:%M</span> "
      }
    '';
  }
]
