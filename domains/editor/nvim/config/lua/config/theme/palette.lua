local M = {}

---@type ThemePalette
local palette = {
  base = "#c2c2b0",
  bright = "#eeeeee",
  dim = "#5e5e5e",
  subtle = "#8c8c7a",
  accent = "#d4c8a8",
  surface = "#2b2b2b",
  bg = "#222222",
  black = "#222222",
  comment = "#6e6e5c",
  green = "#608f60",
  green_bright = "#78a778",
  red = "#b84a4a",
  red_bright = "#d06262",
  yellow = "#c4904a",
  yellow_bright = "#dca862",
  blue = "#6290a0",
  blue_bright = "#7aa8b8",
  magenta = "#a07aaa",
  magenta_bright = "#b892c2",
  cyan = "#5faa8e",
  cyan_bright = "#77c2a6",
}

---@return ThemePalette
M.get = function()
  return palette
end

return M
