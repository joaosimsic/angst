{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;
in
[
  {
    path = "domains/sql-client/sqlit/config/settings.json";
    text = ''
      {
        "theme": "${themeName}",
        "custom_themes": ["${themeName}"],
        "ui_stall_watchdog_ms": 0,
        "query_alert_mode": 0,
        "allow_plaintext_credentials": true
      }
    '';
  }
  {
    path = "domains/sql-client/sqlit/config/themes/${themeName}.json";
    text = ''
      {
        "theme": {
          "name": "${themeName}",
          "dark": true,
          "primary": "#${t.ui.border}",
          "secondary": "#${t.MAGENTA}",
          "accent": "#${t.BRIGHT}",
          "warning": "#${t.WARNING}",
          "error": "#${t.ERROR}",
          "success": "#${t.SUCCESS}",
          "foreground": "#${t.FG}",
          "background": "#${t.BG}",
          "surface": "#${t.BG}",
          "panel": "#${t.BG}",
          "variables": {
            "border": "#${t.BLUE}",
            "block-cursor-background": "#${t.ACCENT}",
            "block-cursor-foreground": "#${t.BG}",
            "block-cursor-text-style": "bold"
          }
        }
      }
    '';
  }
  {
    path = "domains/sql-client/sqlit/config/keymap.json";
    text = ''
      {
        "keymap": {
          "action_keys": {
            "query_insert": {
              "exit_insert_mode": ["escape", "ctrl+c"]
            },
            "query_visual": {
              "exit_visual_mode": ["escape", "v", "ctrl+c"]
            },
            "query_visual_line": {
              "exit_visual_line_mode": ["escape", "V", "ctrl+c"]
            }
          }
        }
      }
    '';
  }
]
