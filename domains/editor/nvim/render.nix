{ themesLib, themeName, ... }:

let
  t = themesLib.get themeName;
in
[
  {
    path = "domains/editor/nvim/config/lua/config/theme/palette.lua";
    text = ''
      local M = {}

      ---@type ThemePalette
      local palette = {
        palette = {
          black = "#${t.palette.black}",
          base = "#${t.palette.base}",
          dim = "#${t.palette.dim}",
          subtle = "#${t.palette.subtle}",
          accent = "#${t.palette.accent}",
          surface = "#${t.palette.surface}",
          overlay = "#${t.palette.overlay}",
        },
        ui = {
          fg = "#${t.ui.fg}",
          bg = "#${t.ui.bg}",
          bright = "#${t.ui.bright}",
          muted = "#${t.ui.muted}",
          comment = "#${t.ui.comment}",
          surface = "#${t.ui.surface}",
          subtle = "#${t.ui.subtle}",
          accent = "#${t.ui.accent}",
          border = "#${t.ui.border}",
          selectionBg = "#${t.ui.selectionBg}",
          selectionFg = "#${t.ui.selectionFg}",
          overlay = "#${t.ui.overlay}",
          prompt = "#${t.ui.prompt}",
        },
        syntax = {
          comment = "#${t.syntax.comment}",
          keyword = "#${t.syntax.keyword}",
          string = "#${t.syntax.string}",
          ["function"] = "#${t.syntax.function}",
          variable = "#${t.syntax.variable}",
          constant = "#${t.syntax.constant}",
          operator = "#${t.syntax.operator}",
          type = "#${t.syntax.type}",
          number = "#${t.syntax.number}",
          punctuation = "#${t.syntax.punctuation}",
        },
        diagnostic = {
          error = "#${t.diagnostic.error}",
          warning = "#${t.diagnostic.warning}",
          info = "#${t.diagnostic.info}",
          hint = "#${t.diagnostic.hint}",
          success = "#${t.diagnostic.success}",
        },
        ansi = {
          normal = {
            black = "#${t.ansi.normal.black}",
            red = "#${t.ansi.normal.red}",
            green = "#${t.ansi.normal.green}",
            yellow = "#${t.ansi.normal.yellow}",
            blue = "#${t.ansi.normal.blue}",
            magenta = "#${t.ansi.normal.magenta}",
            cyan = "#${t.ansi.normal.cyan}",
            white = "#${t.ansi.normal.white}",
          },
          bright = {
            black = "#${t.ansi.bright.black}",
            red = "#${t.ansi.bright.red}",
            green = "#${t.ansi.bright.green}",
            yellow = "#${t.ansi.bright.yellow}",
            blue = "#${t.ansi.bright.blue}",
            magenta = "#${t.ansi.bright.magenta}",
            cyan = "#${t.ansi.bright.cyan}",
            white = "#${t.ansi.bright.white}",
          },
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
