local modes = require("frontend.status.heirline.modes")
local utils = require("frontend.status.heirline.utils")

---@type HeirlineComponent
local Mode = {
	init = function(self)
		self.mode = modes.get_mode_data()
	end,

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
