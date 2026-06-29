local M = {}

---@type ThemePalette
local palette = {
  base = "#c2c2b0",
  bright = "#d7c483",
  dim = "#666666",
  subtle = "#e5c47b",
  accent = "#d7c483",
  surface = "#2b2b2b",
  bg = "#222222",
  black = "#222222",
  comment = "#685742",
  green = "#5f875f",
  green_bright = "#5f875f",
  red = "#685742",
  red_bright = "#685742",
  yellow = "#b36d43",
  yellow_bright = "#b36d43",
  blue = "#78824b",
  blue_bright = "#78824b",
  magenta = "#bb7744",
  magenta_bright = "#bb7744",
  cyan = "#c9a554",
  cyan_bright = "#c9a554",
}

---@return ThemePalette
M.get = function()
  return palette
end

return M
