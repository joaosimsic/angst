local p = require("config.theme.palette")
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
			fg = utils.status_color(self, p.background.base),
			bg = utils.status_color(self, p.accent.variant),
			bold = true,
		}
	end,
}

return M
