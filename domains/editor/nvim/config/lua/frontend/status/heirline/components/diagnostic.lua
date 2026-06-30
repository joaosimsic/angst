---@type ThemeColors
local c = require("config.theme.colors").get()
local icons = require("common.icons")
local conditions = require("heirline.conditions")
local utils = require("frontend.status.heirline.utils")

---@param active_hl_name string
---@param fallback_color string
local function diagnostic_hl(active_hl_name, fallback_color)
	return function(self)
		if utils.is_active(self) then
			return active_hl_name
		end
		return { fg = utils.apply_dark_filter(fallback_color, 0.65), bg = utils.status_bg(self, c.status.bg) }
	end
end

local function space_out(icon)
	return string.format(" %s ", icon)
end

---@type HeirlineComponent
local Diagnostics = {
	condition = function(self)
		local winnr = self.winnr or 0
		if not vim.api.nvim_win_is_valid(winnr) then
			return false
		end
		local bufnr = vim.api.nvim_win_get_buf(winnr)
		return conditions.has_diagnostics(bufnr)
	end,

	init = function(self)
		local winnr = self.winnr or 0
		if not vim.api.nvim_win_is_valid(winnr) then
			self.errors = 0
			self.warnings = 0
			self.hints = 0
			self.info = 0
			return
		end

		local bufnr = vim.api.nvim_win_get_buf(winnr)
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

	update = { "DiagnosticChanged", "BufEnter" },

	hl = function(self)
		return utils.is_active(self) and "HeirlineSurface" or { bg = utils.status_bg(self, c.status.bg) }
	end,

	{
		provider = " ",
	},
	{
		provider = function(self)
			return self.errors > 0 and (self.error_icon .. self.errors) or ""
		end,
		hl = diagnostic_hl("HeirlineDiagnosticError", c.diagnostic.error),
	},
	{
		provider = function(self)
			return self.warnings > 0 and (self.warn_icon .. self.warnings) or ""
		end,
		hl = diagnostic_hl("HeirlineDiagnosticWarn", c.diagnostic.warn),
	},
	{
		provider = function(self)
			return self.info > 0 and (self.info_icon .. self.info) or ""
		end,
		hl = diagnostic_hl("HeirlineDiagnosticInfo", c.diagnostic.info),
	},
	{
		provider = function(self)
			return self.hints > 0 and (self.hint_icon .. self.hints) or ""
		end,
		hl = diagnostic_hl("HeirlineDiagnosticHint", c.diagnostic.hint),
	},
	{
		provider = " ",
	},
}

return {
	Diagnostics = Diagnostics,
}
