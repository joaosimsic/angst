local M = {}

---@type ThemePalette
local palette = {
  palette = {
    background = {
      base = "#0c1014",
      variant = "#0c1014",
    },
    surface = {
      base = "#33859e",
      variant = "#2aa889",
    },
    foreground = {
      base = "#195466",
      variant = "#99d1ce",
    },
    accent = {
      base = "#c23127",
      variant = "#edb443",
    },
    dim = "#4e5166",
  },
  ansi = {
    error = "#e6392e",
    warn = "#fcae1e",
    info = "#26b9db",
    success = "#26cf9c",
  },
}

---@return ThemePalette
M.get = function()
  return palette
end

return M

