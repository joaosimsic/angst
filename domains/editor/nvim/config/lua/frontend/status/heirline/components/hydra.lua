local utils = require("frontend.status.heirline.utils")

---@type HeirlineComponent
local HydraComponent = {
	condition = function()
		return vim.g.active_hydra ~= nil
	end,

	init = function(self)
		---@type ActiveHydraState
		self.hydra = vim.g.active_hydra
	end,

	{
		provider = function(self)
			return string.format(" %s ", self.hydra.name:upper())
		end,
		hl = function(self)
			return {
				fg = utils.status_color(self, self.hydra.fg_color),
				bg = utils.status_color(self, self.hydra.bg_color),
				bold = true,
			}
		end,
	},
}

return { Hydra = HydraComponent }
