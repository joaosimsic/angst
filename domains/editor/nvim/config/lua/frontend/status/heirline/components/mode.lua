local modes = require("frontend.status.heirline.modes")
local utils = require("frontend.status.heirline.utils")
local c = require("config.theme.colors").get()

---@type HeirlineComponent
local Mode = {
	init = function(self)
		if utils.is_active(self) then
			self.mode = modes.get_mode_data()
		else
			self.mode = {
				fg = c.mode.fallbackFg,
				bg = c.mode.fallbackBg,
				label = "INACTIVE",
			}
		end
	end,

	update = {
		"ModeChanged",
		"BufEnter",
		"WinEnter",
		"TermClose",
		"FocusGained",
		"FocusLost",
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
