{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;
  p = t.palette;
in
[
  {
    path = "domains/files/yazi/config/theme.toml";
    text = ''
      [mode]
      normal_main = { bg = "#${p.foreground.variant}", fg = "#${p.background.variant}", bold = true }
      normal_alt  = { fg = "#${p.foreground.variant}", bg = "#${p.background.variant}" }

      [filetype]
      rules = [
          { mime = "image/*", fg = "#${p.surface.variant}" },
          { mime = "video/*", fg = "#${p.accent.variant}" },
          { mime = "inode/empty", fg = "#${p.dim}" },
          { url = "*/", fg = "#${p.surface.base}" }
      ]

      [overall]
      bg = "#${p.background.base}"
    '';
  }
]
