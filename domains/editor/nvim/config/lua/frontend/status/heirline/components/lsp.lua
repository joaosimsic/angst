local conditions = require("heirline.conditions")
local utils = require("frontend.status.heirline.utils")

local provider = utils.to_small_caps(" lsp ")

local LspActive = {
	condition = conditions.lsp_attached,
	update = { "LspAttach", "LspDetach" },
	provider = provider,
	hl = "HeirlineLspActive",
}

local LspInactive = {
	condition = function()
		return not conditions.lsp_attached()
	end,
	provider = provider,
	hl = "HeirlineLspInactive",
}

return {
	LspActive = LspActive,
	LspInactive = LspInactive,
}
