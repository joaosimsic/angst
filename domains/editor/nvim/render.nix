{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;
  p = t.palette;
  a = t.ansi;
in
[
  {
    path = "domains/editor/nvim/config/lua/config/theme/palette.lua";
    text = ''
      local M = {}

      ---@type ThemePalette
      local palette = {
        palette = {
          background = {
            base = "#${p.background.base}",
            variant = "#${p.background.variant}",
          },
          surface = {
            base = "#${p.surface.base}",
            variant = "#${p.surface.variant}",
          },
          foreground = {
            base = "#${p.foreground.base}",
            variant = "#${p.foreground.variant}",
          },
          accent = {
            base = "#${p.accent.base}",
            variant = "#${p.accent.variant}",
          },
          dim = "#${p.dim}",
        },
        ansi = {
          error = "#${a.error}",
          warn = "#${a.warn}",
          info = "#${a.info}",
          success = "#${a.success}",
        },
      }

      ---@return ThemePalette
      M.get = function()
        return palette
      end

      return M
    '';
  }
]
