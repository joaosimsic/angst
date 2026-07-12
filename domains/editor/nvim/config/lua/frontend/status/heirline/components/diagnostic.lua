local palette = require("config.theme.palette").get()
local p = palette.palette
local a = palette.ansi
local icons = require("common.icons")
local utils = require("frontend.status.heirline.utils")

---@param active_hl_name string
---@param fallback_color string
local function diagnostic_hl(active_hl_name, fallback_color)
	return function(self)
		if utils.is_active(self) then
			return active_hl_name
		end
		return { fg = utils.apply_dark_filter(fallback_color, 0.65), bg = utils.status_bg(self, p.background.variant) }
	end
end

local function space_out(icon)
	return string.format(" %s ", icon)
end

---@type HeirlineComponent
local Diagnostics = {
	condition = function(self)
		local bufnr = self.bufnr or 0
		return #vim.diagnostic.get(bufnr) > 0
	end,

	init = function(self)
		local bufnr = self.bufnr or 0
		self.errors = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })
		self.warnings = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.WARN })
		self.hints = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.HINT })
		self.info = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.INFO })
	end,

	static = {
		error_icon = space_out(icons.diagnostics.error),
		warn_icon = space_out(icons.diagnostics.warn),
		info_icon = space_out(icons.diagnostics.info),
		hint_icon = space_out(icons.diagnostics.hint),
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
		return utils.is_active(self) and "HeirlineSurface" or { bg = utils.status_bg(self, p.background.variant) }
	end,

	{
		provider = " ",
	},
	{
		provider = function(self)
			return self.errors > 0 and (self.error_icon .. self.errors) or ""
		end,
		hl = diagnostic_hl("HeirlineDiagnosticError", a.error),
	},
	{
		provider = function(self)
			return self.warnings > 0 and (self.warn_icon .. self.warnings) or ""
		end,
		hl = diagnostic_hl("HeirlineDiagnosticWarn", a.warn),
	},
	{
		provider = function(self)
			return self.info > 0 and (self.info_icon .. self.info) or ""
		end,
		hl = diagnostic_hl("HeirlineDiagnosticInfo", a.info),
	},
	{
		provider = function(self)
			return self.hints > 0 and (self.hint_icon .. self.hints) or ""
		end,
		hl = diagnostic_hl("HeirlineDiagnosticHint", p.surface.base),
	},
	{
		provider = " ",
	},
}

return {
	Diagnostics = Diagnostics,
}
