---@type ThemeColors
local c = require("config.theme.colors").get()
local utils = require("frontend.status.heirline.utils")

---@type HeirlineComponent
local DiagnosticsHistory = {
	condition = function()
		return require("frontend.tools.diagnostics-history").get_count() > 0
	end,

	init = function(self)
		self.count = require("frontend.tools.diagnostics-history").get_count()
	end,

	static = {
		icon = " H:",
	},

	update = {
		"DiagnosticChanged",
		"BufEnter",
		"WinEnter",
		"WinLeave",
		"FocusGained",
		"FocusLost",
	},

	hl = function(self)
		return utils.is_active(self) and "HeirlineSurface" or { bg = utils.status_bg(self, c.status.bg) }
	end,

	{
		provider = " ",
	},
	{
		provider = function(self)
			return self.count > 0 and (self.icon .. self.count) or ""
		end,
		hl = function(self)
			if utils.is_active(self) then
				return "HeirlineDiagnosticHistory"
			end
			return { fg = utils.apply_dark_filter(c.diagnostic.info, 0.65), bg = utils.status_bg(self, c.status.bg) }
		end,
	},
	{
		provider = " ",
	},
}

return {
	DiagnosticsHistory = DiagnosticsHistory,
}
