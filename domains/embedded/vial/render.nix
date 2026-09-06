{ themesLib, themeName }:
let
  t = themesLib.get themeName;
in
[
  {
    path = "domains/embedded/vial/config/theme.json";
    text = builtins.toJSON {
      palette = t.palette;
      ansi = t.ansi;
    };
  }
]
