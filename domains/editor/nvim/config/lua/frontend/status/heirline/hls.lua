local p, a = require("config.theme.palette")

---@param name string
---@param opts vim.api.keyset.highlight
local function hl(name, opts)
	vim.api.nvim_set_hl(0, name, opts)
end

local M = {}

M.setup_highlights = function()
	hl("HeirlineModeNormal", { fg = p.background.base, bg = p.foreground.base, bold = true })
	hl("HeirlineModeInsert", { fg = p.background.base, bg = p.foreground.variant, bold = true })
	hl("HeirlineModeVisual", { fg = p.background.base, bg = p.surface.variant, bold = true })
	hl("HeirlineModeReplace", { fg = p.background.base, bg = p.accent.base, bold = true })
	hl("HeirlineModeCommand", { fg = p.background.base, bg = p.accent.base, bold = true })
	hl("HeirlineModeTerminal", { fg = p.background.base, bg = p.accent.variant, bold = true })

	hl("HeirlineSurface", { fg = p.accent.base, bg = p.background.variant })
	hl("HeirlineSurfaceBold", { fg = p.foreground.variant, bg = p.background.variant, bold = true })
	hl("HeirlineBlack", { fg = p.accent.base, bg = p.background.base })
	hl("HeirlineBlackBright", { fg = p.foreground.variant, bg = p.background.base })

	hl("HeirlineGit", { fg = p.foreground.variant, bg = p.background.variant })
	hl("HeirlineGitAdd", { fg = a.success, bg = p.background.variant })
	hl("HeirlineGitChange", { fg = a.warn, bg = p.background.variant })
	hl("HeirlineGitDelete", { fg = a.error, bg = p.background.variant })

	hl("HeirlineDiagnosticError", { fg = a.error, bg = p.background.variant })
	hl("HeirlineDiagnosticWarn", { fg = a.warn, bg = p.background.variant })
	hl("HeirlineDiagnosticInfo", { fg = a.info, bg = p.background.variant })
	hl("HeirlineDiagnosticHint", { fg = p.surface.base, bg = p.background.variant })

	hl("HeirlineDiagnosticHistory", { fg = a.info, bg = p.background.variant })

	hl("HeirlineLspActive", { fg = p.foreground.variant, bg = p.background.variant })
	hl("HeirlineLspInactive", { fg = p.dim, bg = p.background.variant })

	hl("HeirlinePosition", { fg = p.background.base, bg = p.accent.variant, bold = true })
end

return M
