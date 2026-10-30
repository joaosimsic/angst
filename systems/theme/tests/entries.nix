{ themeSys, themeNames }:

map (themeName: builtins.seq (themeSys.get themeName) "  ${themeName}: ok") themeNames
