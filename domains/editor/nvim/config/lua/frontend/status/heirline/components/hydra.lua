local utils = require("frontend.status.heirline.utils")

---@type HeirlineComponent
local HydraComponent = {
	condition = function()
		return vim.g.active_hydra ~= nil
	end,

	update = {
		"User",
		pattern = "HydraChanged",
		callback = vim.schedule_wrap(function()
			vim.cmd("redrawstatus")
		end),
	},

	{
		provider = function()
			local hydra = vim.g.active_hydra
			if hydra == nil then
				return ""
			end

			return string.format(" %s ", hydra.name:upper())
		end,
		hl = function(self)
			local hydra = vim.g.active_hydra
			if hydra == nil then
				return {}
			end

			return {
				fg = utils.status_color(self, hydra.fg_color),
				bg = utils.status_color(self, hydra.bg_color),
				bold = true,
			}
		end,
	},
}

return { Hydra = HydraComponent }
