{ themesLib, themeNames }:

map (themeName: builtins.seq (themesLib.get themeName) "  ${themeName}: ok") themeNames
