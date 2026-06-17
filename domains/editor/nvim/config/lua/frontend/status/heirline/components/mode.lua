local modes = require("frontend.status.heirline.modes")

local Mode = {
	init = function(self)
		self.mode = modes.get_mode_data()
	end,

	hl = function()
		return modes.mode_hl_name()
	end,

	{
		provider = function(self)
			return " " .. self.mode.label .. " "
		end,
	},
}

return { Mode = Mode }
