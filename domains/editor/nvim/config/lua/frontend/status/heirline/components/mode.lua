local modes = require("frontend.status.heirline.modes")
local utils = require("frontend.status.heirline.utils")

---@type HeirlineComponent
local Mode = {
	init = function(self)
		if utils.is_active(self) then
			self.mode = modes.get_mode_data()
		else
			self.mode = {
				fg = require("config.theme.palette").get().dim,
				bg = require("config.theme.palette").get().surface,
				label = "INACTIVE",
			}
		end
	end,

	update = {
		"ModeChanged",
		"BufEnter",
		"WinEnter",
	},

	hl = function(self)
		return {
			fg = utils.status_color(self, self.mode.fg),
			bg = utils.status_color(self, self.mode.bg),
			bold = true,
		}
	end,

	{
		provider = function(self)
			return " " .. self.mode.label .. " "
		end,
	},
}

return { Mode = Mode }
