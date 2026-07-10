{
  themesLib,
  themeName,
  checkHelpers,
  fontFamily,
  ...
}:

let
  t = themesLib.get themeName;
  inherit (checkHelpers) requireInfix;

  colorsText = ''
    background           = ${t.BLACK}
    foreground           = ${t.BASE}
    cursor-color         = ${t.BASE}
    selection-background = ${t.SUBTLE}
    selection-foreground = ${t.BASE}
    palette = 0=#${t.BLACK}
    palette = 1=#${t.RED}
    palette = 2=#${t.GREEN}
    palette = 3=#${t.YELLOW}
    palette = 4=#${t.BLUE}
    palette = 5=#${t.MAGENTA}
    palette = 6=#${t.CYAN}
    palette = 7=#${t.BASE}
    palette = 8=#${t.DIM}
    palette = 9=#${t.RED}
    palette = 10=#${t.GREEN}
    palette = 11=#${t.YELLOW}
    palette = 12=#${t.BLUE}
    palette = 13=#${t.MAGENTA}
    palette = 14=#${t.CYAN}
    palette = 15=#${t.BASE}
  '';
in
[
  {
    path = "domains/terminal/ghostty/config/config";
    text = ''
      config-file = colors.conf

      font-family = ${fontFamily}
      font-size = 13

      adjust-underline-thickness = 100%

      cursor-style = block
      cursor-style-blink = false

      window-decoration = false

      window-padding-x = 8
      window-padding-y = 8
      window-padding-balance = true

      background-opacity = 1.0

      bold-is-bright = true

      font-feature = +calt
      font-feature = +liga
      font-feature = +dlig

      scrollback-limit = 10000

      clipboard-write = allow

      keybind = ctrl+q=text:\x11
    '';
  }
  {
    path = "domains/terminal/ghostty/config/colors.conf";
    text = colorsText;
    checks = [
      (requireInfix colorsText "palette = 5=#${t.MAGENTA}"
        "ghostty palette slot 5 should render ${themeName} MAGENTA"
      )
      (requireInfix colorsText "palette = 13=#${t.MAGENTA}"
        "ghostty palette slot 13 should render ${themeName} MAGENTA"
      )
      (requireInfix colorsText "palette = 1=#${t.RED}"
        "ghostty palette slot 1 should render ${themeName} RED"
      )
    ];
  }
]
