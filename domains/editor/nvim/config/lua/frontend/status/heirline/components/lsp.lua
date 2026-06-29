local conditions = require("heirline.conditions")
local utils = require("frontend.status.heirline.utils")

---@type ThemePalette
local p = require("config.theme.palette").get()
local provider = utils.to_small_caps(" lsp ")

---@type HeirlineComponent
local LspActive = {
	condition = conditions.lsp_attached,
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
