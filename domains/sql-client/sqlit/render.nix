{ themesLib, themeName, checkHelpers, ... }:

let
  t = themesLib.get themeName;
  inherit (checkHelpers) requireInfix require;

  settingsText = ''
    {
      "theme": "${themeName}",
      "custom_themes": ["${themeName}"],
      "ui_stall_watchdog_ms": 0,
      "query_alert_mode": 0,
      "allow_plaintext_credentials": true
    }
  '';

  themeFileText = ''
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
in
[
  {
    path = "domains/sql-client/sqlit/config/settings.json";
    text = settingsText;
    checks = [
      (requireInfix settingsText ''"theme": "${themeName}"''
        "sqlit settings theme name should be ${themeName}")
      (requireInfix settingsText ''"custom_themes": ["${themeName}"]''
        "sqlit custom_themes should reference ${themeName}")
    ];
  }
  {
    path = "domains/sql-client/sqlit/config/themes/${themeName}.json";
    text = themeFileText;
    checks = [
      (requireInfix themeFileText ''"name": "${themeName}"''
        "sqlit theme file name should be ${themeName}")
      (requireInfix themeFileText ''"dark": true''
        "sqlit theme should be dark")
      (requireInfix themeFileText ''"primary": "#${t.ui.border}"''
        "sqlit primary should render ${themeName} ui.border")
      (requireInfix themeFileText ''"secondary": "#${t.MAGENTA}"''
        "sqlit secondary should render ${themeName} MAGENTA")
      (requireInfix themeFileText ''"accent": "#${t.ui.bright}"''
        "sqlit accent should render ${themeName} ui.bright")
      (requireInfix themeFileText ''"warning": "#${t.WARNING}"''
        "sqlit warning should render ${themeName} WARNING")
      (requireInfix themeFileText ''"error": "#${t.ERROR}"''
        "sqlit error should render ${themeName} ERROR")
      (requireInfix themeFileText ''"success": "#${t.SUCCESS}"''
        "sqlit success should render ${themeName} SUCCESS")
      (requireInfix themeFileText ''"foreground": "#${t.FG}"''
        "sqlit foreground should render ${themeName} FG")
      (requireInfix themeFileText ''"background": "#${t.BG}"''
        "sqlit background should render ${themeName} BG")
      (requireInfix themeFileText ''"surface": "#${t.BG}"''
        "sqlit surface should render ${themeName} BG")
      (requireInfix themeFileText ''"panel": "#${t.BG}"''
        "sqlit panel should render ${themeName} BG")
      (requireInfix themeFileText ''"border": "#${t.BLUE}"''
        "sqlit border variable should render ${themeName} BLUE")
      (require (t.BLUE != t.MAGENTA)
        "sqlit primary BLUE and secondary MAGENTA must differ in ${themeName}")
      (require (t.BG != t.SURFACE)
        "sqlit background and surface must differ in ${themeName}")
      (require (t.ERROR != t.SUCCESS)
        "sqlit ERROR and SUCCESS must differ in ${themeName}")
    ];
  }
]
