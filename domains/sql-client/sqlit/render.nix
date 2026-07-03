{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;
in
[
  {
    path = "domains/sql-client/sqlit/config/sqlit/settings.json";
    text = ''
      {
        "theme": "angst",
        "custom_themes": [
          {
            "name": "angst",
            "primary": "#${t.BLUE}",
            "secondary": "#${t.MAGENTA}",
            "accent": "#${t.BRIGHT}",
            "background": "#${t.BG}",
            "surface": "#${t.SURFACE}",
            "error": "#${t.ERROR}",
            "success": "#${t.SUCCESS}",
            "warning": "#${t.WARNING}"
          }
        ]
      }
    '';
  }
]
