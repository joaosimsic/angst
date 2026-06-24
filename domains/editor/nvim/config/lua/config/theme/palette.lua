local M = {}

---@type ThemePalette
local palette = {
  base = "#c5c9c5",
  bright = "#c8c093",
  dim = "#2d4f67",
  surface = "#211f1f",
  bg = "#181616",
  black = "#181616",
  comment = "#a292a3",
  green = "#8a9a7b",
  green_bright = "#a2b293",
  red = "#c4746e",
  red_bright = "#dc8c86",
  yellow = "#c4b28a",
  yellow_bright = "#dccaa2",
  blue = "#8ba4b0",
  blue_bright = "#a3bcc8",
  magenta = "#a292a3",
  magenta_bright = "#baaabb",
  cyan = "#8ea4a2",
  cyan_bright = "#a6bcba",
}

---@return ThemePalette
M.get = function()
  return palette
end

return M
