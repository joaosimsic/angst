local utils = require("frontend.status.heirline.utils")

---@type HeirlineComponent
local HydraComponent = {
	condition = function()
		if vim.g.active_hydra == nil then
			return false
		end

		local current_buf = vim.api.nvim_get_current_buf()
		local keymaps = vim.api.nvim_buf_get_keymap(current_buf, "n")

		local has_hydra_mappings = false
		for _, map in ipairs(keymaps) do
			if map.desc and (map.desc:find("Hydra") or map.desc:find("DOKTOR")) then
				has_hydra_mappings = true
				break
			end
		end

		return has_hydra_mappings
	end,

	init = function(self)
		---@type ActiveHydraState
		self.hydra = vim.g.active_hydra
	end,

	update = {
		"ModeChanged",
		"BufEnter",
		"WinEnter",
	},

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
