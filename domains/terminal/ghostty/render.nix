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

  p = t.palette;

  colorsText = ''
    background           = ${p.background.base}
    foreground           = ${p.foreground.variant}
    cursor-color         = ${p.foreground.variant}
    selection-background = ${p.accent.base}
    selection-foreground = ${p.foreground.variant}
    palette = 0=#${p.background.variant}
    palette = 1=#${p.dim}
    palette = 2=#${p.surface.variant}
    palette = 3=#${p.accent.base}
    palette = 4=#${p.surface.base}
    palette = 5=#${p.accent.variant}
    palette = 6=#${p.foreground.base}
    palette = 7=#${p.foreground.variant}
    palette = 8=#${p.dim}
    palette = 9=#${p.dim}
    palette = 10=#${p.surface.variant}
    palette = 11=#${p.accent.base}
    palette = 12=#${p.surface.base}
    palette = 13=#${p.accent.variant}
    palette = 14=#${p.foreground.base}
    palette = 15=#${p.foreground.variant}
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
      (requireInfix colorsText "palette = 5=#${p.accent.variant}"
        "ghostty palette slot 5 should render ${themeName} accent.variant"
      )
      (requireInfix colorsText "palette = 13=#${p.accent.variant}"
        "ghostty palette slot 13 should render ${themeName} accent.variant"
      )
      (requireInfix colorsText "palette = 1=#${p.dim}"
        "ghostty palette slot 1 should render ${themeName} dim"
      )
    ];
  }
]
