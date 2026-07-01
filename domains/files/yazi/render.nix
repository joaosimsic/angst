{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;
in
[
  {
    path = "domains/files/yazi/config/theme.toml";
    text = ''
      [mode]
      normal_main = { bg = "#${t.BRIGHT}", fg = "#${t.SURFACE}", bold = true }
      normal_alt  = { fg = "#${t.BRIGHT}", bg = "#${t.SURFACE}" }

      [filetype]
      rules = [
          { mime = "image/*", fg = "#${t.GREEN}" },
          { mime = "video/*", fg = "#${t.MAGENTA}" },
          { mime = "inode/empty", fg = "#${t.DIM}" },
          { url = "*/", fg = "#${t.BLUE}" }
      ]

      [overall]
      bg = "#${t.BG}"
    '';
  }
]
