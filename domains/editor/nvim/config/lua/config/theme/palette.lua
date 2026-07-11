local M = {}

---@type ThemePalette
local palette = {
  palette = {
    background = {
      base = "#010409",
      variant = "#0d1117",
    },
    surface = {
      base = "#3fb950",
      variant = "#58a6ff",
    },
    foreground = {
      base = "#bc8cff",
      variant = "#b1bac4",
    },
    accent = {
      base = "#ff7b72",
      variant = "#d29922",
    },
    dim = "#484f58",
  },
  ansi = {
    error = "#ff6e6e",
    warn = "#f2b134",
    info = "#58a6ff",
    success = "#3fb950",
  },
}

---@return ThemePalette
M.get = function()
  return palette
end

return M

