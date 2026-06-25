---@type ThemePalette
local p = require("config.theme.palette").get()
local icons = require("common.icons")
local conditions = require("heirline.conditions")
local utils = require("frontend.status.heirline.utils")

---@param color string
---@return fun(self: table): vim.api.keyset.highlight
local function diagnostic_hl(color)
	return function(self)
		return { fg = utils.status_color(self, color), bg = utils.status_bg(self, p.surface) }
	end
end

---@param icon string
---@return string
local space_out = function(icon)
	return string.format(" %s ", icon)
end

---@type HeirlineComponent
local Diagnostics = {
	condition = conditions.has_diagnostics,

	static = {
		error_icon = space_out(icons.diagnostics.error),
		warn_icon = space_out(icons.diagnostics.warn),
		info_icon = space_out(icons.diagnostics.info),
		hint_icon = space_out(icons.diagnostics.hint),
	},

	init = function(self)
		self.errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
		self.warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
		self.hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
		self.info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
	end,

	update = { "DiagnosticChanged", "BufEnter" },

	hl = function(self)
		return { bg = utils.status_bg(self, p.surface) }
	end,

	{
		provider = " ",
		hl = function(self)
			return { bg = utils.status_bg(self, p.surface) }
		end,
	},

	{
		provider = function(self)
			return self.errors > 0 and (self.error_icon .. self.errors) or ""
		end,
		hl = diagnostic_hl(p.red),
	},

	{
		provider = function(self)
			return self.warnings > 0 and (self.warn_icon .. self.warnings) or ""
		end,
		hl = diagnostic_hl(p.yellow),
	},

	{
		provider = function(self)
			return self.info > 0 and (self.info_icon .. self.info) or ""
		end,
		hl = diagnostic_hl(p.blue),
	},

	{
		provider = function(self)
			return self.hints > 0 and (self.hint_icon .. self.hints) or ""
		end,
		hl = diagnostic_hl(p.cyan),
	},

	{
		provider = " ",
		hl = function(self)
			return { bg = utils.status_bg(self, p.surface) }
		end,
	},
}

return {
	Diagnostics = Diagnostics,
}
