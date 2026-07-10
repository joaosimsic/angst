local palette = require("config.theme.palette").get()
local p = palette.palette
local utils = require("frontend.status.heirline.utils")

---@type HeirlineComponent
local Anchor = {
	condition = function()
		return vim.g.anchor_path ~= nil
	end,

	init = function(self)
		self.anchor_name = vim.g.anchor_path and vim.g.anchor_path.name or nil
	end,

	hl = function(self)
		if utils.is_active(self) then
			return "HeirlineSurface"
		end
		return { fg = utils.apply_dark_filter(p.accent.base, 0.65), bg = utils.status_bg(self, p.background.variant) }
	end,

	{
		provider = function(self)
			if not self.anchor_name then
				return ""
			end
			return "  " .. self.anchor_name .. " "
		end,
	},
}

return { Anchor = Anchor }
