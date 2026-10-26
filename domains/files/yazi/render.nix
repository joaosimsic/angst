{
  lib,
  host,
  homeDirectory,
  themesLib,
  themeName,
}:

let
  t = themesLib.get themeName;
  p = t.palette;
  a = t.ansi;

  persistPaths = import ../../../lib/persist-paths.nix {
    inherit lib host homeDirectory;
  };

  luaList =
    values:
    if values == [ ] then "{ }" else "{ " + lib.concatMapStringsSep ", " builtins.toJSON values + " }";
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

      [app]
      overall = { bg = "#${p.background.base}" }

      [git]
      ignored   = { fg = "#${p.dim}" }
      untracked = { fg = "#${a.info}" }
      unstaged  = { fg = "#${a.warn}" }
      staged    = { fg = "#${a.success}" }
      added     = { fg = "#${a.success}" }
      deleted   = { fg = "#${a.error}" }
      updated   = { fg = "#${a.warn}" }
    '';
  }
  {
    path = "domains/files/yazi/config/init.lua";
    text = ''
      local persist = require("persist-status")

      persist.setup({
        roots = ${luaList persistPaths.roots},
        files = ${luaList persistPaths.homeFiles},
        icon = "󰋊",
        fg = "#${p.accent.variant}",
      })

      require("git"):setup({ order = 1500 })

      function Linemode:persist()
        return persist.marker(self._file.url, self._file.is_hovered)
      end
    '';
  }
]
