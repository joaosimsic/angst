local c = require("config.theme.colors").get()

---@param name string
---@param opts vim.api.keyset.highlight
local function hl(name, opts)
	vim.api.nvim_set_hl(0, name, opts)
end

local M = {}

M.setup_highlights = function()
	hl("HeirlineModeNormal", { fg = c.mode.fg, bg = c.mode.normal, bold = true })
	hl("HeirlineModeInsert", { fg = c.mode.fg, bg = c.mode.insert, bold = true })
	hl("HeirlineModeVisual", { fg = c.mode.fg, bg = c.mode.visual, bold = true })
	hl("HeirlineModeReplace", { fg = c.mode.fg, bg = c.mode.replace, bold = true })
	hl("HeirlineModeCommand", { fg = c.mode.fg, bg = c.mode.command, bold = true })
	hl("HeirlineModeTerminal", { fg = c.mode.fg, bg = c.mode.terminal, bold = true })

	hl("HeirlineSurface", { fg = c.status.fg, bg = c.status.bg })
	hl("HeirlineSurfaceBold", { fg = c.status.active, bg = c.status.bg, bold = true })
	hl("HeirlineBlack", { fg = c.status.fg, bg = c.editor.bg })
	hl("HeirlineBlackBright", { fg = c.status.active, bg = c.editor.bg })

	hl("HeirlineGit", { fg = c.git.branch, bg = c.status.bg })
	hl("HeirlineGitAdd", { fg = c.git.add, bg = c.status.bg })
	hl("HeirlineGitChange", { fg = c.git.change, bg = c.status.bg })
	hl("HeirlineGitDelete", { fg = c.git.delete, bg = c.status.bg })

	hl("HeirlineDiagnosticError", { fg = c.diagnostic.error, bg = c.status.bg })
	hl("HeirlineDiagnosticWarn", { fg = c.diagnostic.warn, bg = c.status.bg })
	hl("HeirlineDiagnosticInfo", { fg = c.diagnostic.info, bg = c.status.bg })
	hl("HeirlineDiagnosticHint", { fg = c.diagnostic.hint, bg = c.status.bg })

	hl("HeirlineDiagnosticHistory", { fg = c.diagnostic.info, bg = c.status.bg })

	hl("HeirlineLspActive", { fg = c.status.active, bg = c.status.bg })
	hl("HeirlineLspInactive", { fg = c.status.inactive, bg = c.status.bg })

	hl("HeirlinePosition", { fg = c.status.positionFg, bg = c.status.positionBg, bold = true })
end

return M
