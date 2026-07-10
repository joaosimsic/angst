local conditions = require("heirline.conditions")
local utils = require("frontend.status.heirline.utils")

local palette = require("config.theme.palette").get()
local p = palette.palette
local provider = utils.to_small_caps(" lsp ")

---@type HeirlineComponent
local LspActive = {
	condition = conditions.lsp_attached,

	update = { "LspAttach", "LspDetach", "WinEnter", "WinLeave", "BufEnter", "FocusGained", "FocusLost" },

	provider = provider,

	hl = function(self)
		return { fg = utils.status_color(self, p.foreground.variant), bg = utils.status_bg(self, p.background.variant) }
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
		return { fg = utils.status_color(self, p.dim), bg = utils.status_bg(self, p.background.variant) }
	end,
}

return {
	LspActive = LspActive,
	LspInactive = LspInactive,
}
