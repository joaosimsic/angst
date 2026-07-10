local palette = require("config.theme.palette").get()
local p = palette.palette
local a = palette.ansi

local keys = {
  fg = p.foreground.base,
  bg = p.background.base,
  base = p.foreground.base,
  black = p.background.base,
  bright = p.foreground.variant,
  dim = p.dim,
  subtle = p.accent.base,
  accent = p.accent.base,
  surface = p.background.variant,
  comment = p.dim,
  red = a.error,
  red_bright = p.dim,
  green = a.success,
  green_bright = p.surface.variant,
  yellow = a.warn,
  yellow_bright = p.accent.base,
  blue = p.surface.base,
  blue_bright = p.surface.base,
  magenta = p.accent.variant,
  magenta_bright = p.accent.variant,
  cyan = a.info,
  cyan_bright = p.foreground.base,
}

local M = {}

---@param key ThemeColorKey|nil
---@return string
M.resolve = function(key)
  return keys[key or "fg"] or p.foreground.base
end

return M
