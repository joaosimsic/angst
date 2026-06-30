---@type ThemeColors
local c = require("config.theme.colors").get()
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
		return {
			fg = utils.status_color(self, c.status.positionFg),
			bg = utils.status_color(self, c.status.positionBg),
			bold = true,
		}
	end,
}

return M
