{
  themeSys,
  themeName,
  checkHelpers,
}:

let
  t = themeSys.get themeName;
  inherit (checkHelpers) requireInfix;

  p = t.palette;

  conf = ''
    osc = yes

    osd-color = "#${p.foreground.variant}"
    osd-outline-color = "#${p.background.base}"

    sub-color = "#${p.foreground.variant}"
    sub-border-color = "#${p.background.base}"
  '';
in
[
  {
    path = "domains/media/celluloid/config/mpv.conf";
    text = conf;
    checks = [
      (requireInfix conf "osd-color = \"#${p.foreground.variant}\""
        "celluloid osd-color should render ${themeName} foreground.variant"
      )
      (requireInfix conf "sub-color = \"#${p.foreground.variant}\""
        "celluloid sub-color should render ${themeName} foreground.variant"
      )
      (requireInfix conf "osd-outline-color = \"#${p.background.base}\""
        "celluloid osd-outline-color should render ${themeName} background.base"
      )
    ];
  }
]
