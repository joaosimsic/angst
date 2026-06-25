---@type ThemePalette
local p = require("config.theme.palette").get()
local utils = require("frontend.status.heirline.utils")

local M = {}

---@type HeirlineComponent
M.Align = { provider = "%=" }

---@type HeirlineComponent
M.Space = { provider = " " }

---@type HeirlineComponent
M.Ruler = {
	provider = " %l:%c | %P ",
	hl = function(self)
		return { fg = utils.status_color(self, p.black), bg = utils.status_color(self, p.magenta_bright), bold = true }
	end,
}

return M
