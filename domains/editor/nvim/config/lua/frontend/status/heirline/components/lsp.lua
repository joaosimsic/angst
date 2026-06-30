local conditions = require("heirline.conditions")
local utils = require("frontend.status.heirline.utils")

---@type ThemePalette
local p = require("config.theme.palette").get()
local provider = utils.to_small_caps(" lsp ")

---@type HeirlineComponent
local LspActive = {
	condition = function(self)
		local winnr = self.winnr or 0
		if not vim.api.nvim_win_is_valid(winnr) then
			return false
		end
		local bufnr = vim.api.nvim_win_get_buf(winnr)
		return next(vim.lsp.get_clients({ bufnr = bufnr })) ~= nil
	end,

	update = { "LspAttach", "LspDetach", "WinEnter", "WinLeave", "BufEnter" },

	init = function(self)
		self.is_active = conditions.is_active()
	end,

	provider = provider,

	hl = function(self)
		return { fg = utils.status_color(self, p.bright), bg = utils.status_bg(self, p.surface) }
	end,
}

---@type HeirlineComponent
local LspInactive = {
	condition = function()
		return not conditions.lsp_attached()
	end,

	update = { "WinEnter", "WinLeave", "BufEnter" },

	init = function(self)
		self.is_active = conditions.is_active()
	end,

	provider = provider,

	hl = function(self)
		return { fg = utils.status_color(self, p.dim), bg = utils.status_bg(self, p.surface) }
	end,
}

return {
	LspActive = LspActive,
	LspInactive = LspInactive,
}
