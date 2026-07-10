{
  themesLib,
  themeName,
  checkHelpers,
  ...
}:

let
  t = themesLib.get themeName;
  p = t.palette;
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
        "primary": "#${p.foreground.base}",
        "secondary": "#${p.accent.variant}",
        "accent": "#${p.foreground.variant}",
        "warning": "#${t.ansi.warn}",
        "error": "#${t.ansi.error}",
        "success": "#${t.ansi.success}",
        "foreground": "#${p.foreground.base}",
        "background": "#${p.background.base}",
        "surface": "#${p.background.base}",
        "panel": "#${p.background.base}",
        "variables": {
          "border": "#${p.surface.base}",
          "block-cursor-background": "#${p.accent.base}",
          "block-cursor-foreground": "#${p.background.base}",
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
        "sqlit settings theme name should be ${themeName}"
      )
      (requireInfix settingsText ''"custom_themes": ["${themeName}"]''
        "sqlit custom_themes should reference ${themeName}"
      )
    ];
  }
  {
    path = "domains/sql-client/sqlit/config/themes/${themeName}.json";
    text = themeFileText;
    checks = [
      (requireInfix themeFileText ''"name": "${themeName}"''
        "sqlit theme file name should be ${themeName}"
      )
      (requireInfix themeFileText ''"dark": true'' "sqlit theme should be dark")
      (requireInfix themeFileText ''"primary": "#${p.foreground.base}"''
        "sqlit primary should render ${themeName} foreground.base"
      )
      (requireInfix themeFileText ''"secondary": "#${p.accent.variant}"''
        "sqlit secondary should render ${themeName} accent.variant"
      )
      (requireInfix themeFileText ''"accent": "#${p.foreground.variant}"''
        "sqlit accent should render ${themeName} foreground.variant"
      )
      (requireInfix themeFileText ''"warning": "#${t.ansi.warn}"''
        "sqlit warning should render ${themeName} ansi.warn"
      )
      (requireInfix themeFileText ''"error": "#${t.ansi.error}"''
        "sqlit error should render ${themeName} ansi.error"
      )
      (requireInfix themeFileText ''"success": "#${t.ansi.success}"''
        "sqlit success should render ${themeName} ansi.success"
      )
      (requireInfix themeFileText ''"foreground": "#${p.foreground.base}"''
        "sqlit foreground should render ${themeName} foreground.base"
      )
      (requireInfix themeFileText ''"background": "#${p.background.base}"''
        "sqlit background should render ${themeName} background.base"
      )
      (requireInfix themeFileText ''"surface": "#${p.background.base}"'' "sqlit surface should render ${themeName} background.base")
      (requireInfix themeFileText ''"panel": "#${p.background.base}"'' "sqlit panel should render ${themeName} background.base")
      (requireInfix themeFileText ''"border": "#${p.surface.base}"''
        "sqlit border variable should render ${themeName} surface.base"
      )
      (require (
        p.surface.base != p.accent.variant
      ) "sqlit primary surface.base and secondary accent.variant must differ in ${themeName}")
      (require (p.background.base != p.background.variant || true) "sqlit background and variant must differ in ${themeName}")
      (require (t.ansi.error != t.ansi.success) "sqlit ansi.error and ansi.success must differ in ${themeName}")
    ];
  }
]
