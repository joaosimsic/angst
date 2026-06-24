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
				fg = self.hydra.fg_color,
				bg = self.hydra.bg_color,
				bold = true,
			}
		end,
	},
}

return { Hydra = HydraComponent }
