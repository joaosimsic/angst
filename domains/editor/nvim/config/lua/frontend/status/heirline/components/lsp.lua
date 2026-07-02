local conditions = require("heirline.conditions")
local utils = require("frontend.status.heirline.utils")

---@type ThemeColors
local c = require("config.theme.colors").get()
local provider = utils.to_small_caps(" lsp ")

---@type HeirlineComponent
local LspActive = {
	condition = conditions.lsp_attached,

	update = { "LspAttach", "LspDetach", "WinEnter", "WinLeave", "BufEnter", "FocusGained", "FocusLost" },

	provider = provider,

	hl = function(self)
		return { fg = utils.status_color(self, c.status.active), bg = utils.status_bg(self, c.status.bg) }
	end,
}

---@type HeirlineComponent
local LspInactive = {
	condition = function()
		return not conditions.lsp_attached()
	end,

	update = { "LspAttach", "LspDetach", "WinEnter", "WinLeave", "BufEnter", "FocusGained", "FocusLost" },

	provider = provider,

	hl = function(self)
		return { fg = utils.status_color(self, c.status.inactive), bg = utils.status_bg(self, c.status.bg) }
	end,
}

return {
	LspActive = LspActive,
	LspInactive = LspInactive,
}
