---@type ThemePalette
local p = require("config.theme.palette").get()

---@type HeirlineComponent
local HydraComponent = {
	condition = function()
		return vim.g.active_hydra ~= nil
	end,

	init = function(self)
		self.hydra = vim.g.active_hydra
	end,

	{
		provider = function(self)
			return string.format(" %s ", self.hydra.name:upper())
		end,
		hl = function(self)
			return { bg = self.hydra.color, fg = p.bg, bold = true }
		end,
	},
}

return { Hydra = HydraComponent }
