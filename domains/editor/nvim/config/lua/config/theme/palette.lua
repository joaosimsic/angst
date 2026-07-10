local M = {}

---@type ThemePalette
local palette = {
  palette = {
    background = {
      base = "#222222",
      variant = "#000000",
    },
    surface = {
      base = "#78824b",
      variant = "#5f875f",
    },
    foreground = {
      base = "#c9a554",
      variant = "#d7c483",
    },
    accent = {
      base = "#b36d43",
      variant = "#bb7744",
    },
    dim = "#685742",
  },
  ansi = {
    error = "#ff3333",
    warn = "#ffaa00",
    info = "#33b5e5",
    success = "#00c851",
  },
}

---@return ThemePalette
M.get = function()
  return palette
end

return M

