{ themesLib, themeNames }:

map
  (themeName:
    let
      _ = themesLib.get themeName;
    in
    "  ${themeName}: ok")
  themeNames
