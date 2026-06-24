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

	hl = { fg = p.surface, bold = true },

	{
		provider = function(self)
			return string.format(" %s ", self.hydra.name:upper())
		end,
		hl = { bg = p.blue_bright, fg = p.bg, bold = true },
	},
}

return { Hydra = HydraComponent }
