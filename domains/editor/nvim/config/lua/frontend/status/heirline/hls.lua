local p = require("config.theme.palette").get()

---@param name string
---@param opts vim.api.keyset.highlight
local function hl(name, opts)
	vim.api.nvim_set_hl(0, name, opts)
end

local M = {}

M.setup_highlights = function()
	hl("HeirlineModeNormal", { fg = p.black, bg = p.base, bold = true })
	hl("HeirlineModeInsert", { fg = p.black, bg = p.bright, bold = true })
	hl("HeirlineModeVisual", { fg = p.black, bg = p.green_bright, bold = true })
	hl("HeirlineModeReplace", { fg = p.black, bg = p.yellow_bright, bold = true })
	hl("HeirlineModeCommand", { fg = p.black, bg = p.red_bright, bold = true })
	hl("HeirlineModeTerminal", { fg = p.black, bg = p.magenta_bright, bold = true })

	hl("HeirlineSurface", { fg = p.subtle, bg = p.surface })
	hl("HeirlineSurfaceBold", { fg = p.bright, bg = p.surface, bold = true })
	hl("HeirlineBlack", { fg = p.subtle, bg = p.black })
	hl("HeirlineBlackBright", { fg = p.bright, bg = p.black })

	hl("HeirlineGit", { fg = p.bright, bg = p.surface })
	hl("HeirlineGitAdd", { fg = p.green, bg = p.surface })
	hl("HeirlineGitChange", { fg = p.yellow, bg = p.surface })
	hl("HeirlineGitDelete", { fg = p.red, bg = p.surface })

	hl("HeirlineDiagnosticError", { fg = p.red, bg = p.surface })
	hl("HeirlineDiagnosticWarn", { fg = p.yellow, bg = p.surface })
	hl("HeirlineDiagnosticInfo", { fg = p.blue, bg = p.surface })
	hl("HeirlineDiagnosticHint", { fg = p.cyan, bg = p.surface })

	hl("HeirlineLspActive", { fg = p.bright, bg = p.surface })
	hl("HeirlineLspInactive", { fg = p.dim, bg = p.surface })

	hl("HeirlinePosition", { fg = p.black, bg = p.magenta_bright, bold = true })
end

return M
