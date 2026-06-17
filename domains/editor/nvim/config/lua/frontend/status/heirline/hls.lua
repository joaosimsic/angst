local c = require("config.theme").colors

---@param name string
---@param opts vim.api.keyset.highlight
local function hl(name, opts)
	vim.api.nvim_set_hl(0, name, opts)
end

local M = {}

M.setup_highlights = function()
	hl("HeirlineModeNormal", { fg = c.black, bg = c.base, bold = true })
	hl("HeirlineModeInsert", { fg = c.black, bg = c.bright, bold = true })
	hl("HeirlineModeVisual", { fg = c.black, bg = c.green_bright, bold = true })
	hl("HeirlineModeReplace", { fg = c.black, bg = c.yellow_bright, bold = true })
	hl("HeirlineModeCommand", { fg = c.black, bg = c.red_bright, bold = true })
	hl("HeirlineModeTerminal", { fg = c.black, bg = c.magenta_bright, bold = true })

	hl("HeirlineSurface", { fg = c.base, bg = c.surface })
	hl("HeirlineSurfaceBold", { fg = c.bright, bg = c.surface, bold = true })
	hl("HeirlineBlack", { fg = c.base, bg = c.black })
	hl("HeirlineBlackBright", { fg = c.bright, bg = c.black })

	hl("HeirlineGit", { fg = c.bright, bg = c.surface })
	hl("HeirlineGitAdd", { fg = c.green, bg = c.surface })
	hl("HeirlineGitChange", { fg = c.yellow, bg = c.surface })
	hl("HeirlineGitDelete", { fg = c.red, bg = c.surface })

	hl("HeirlineDiagnosticError", { fg = c.red, bg = c.surface })
	hl("HeirlineDiagnosticWarn", { fg = c.yellow, bg = c.surface })
	hl("HeirlineDiagnosticInfo", { fg = c.blue, bg = c.surface })
	hl("HeirlineDiagnosticHint", { fg = c.cyan, bg = c.surface })

	hl("HeirlineLspActive", { fg = c.bright, bg = c.surface })
	hl("HeirlineLspInactive", { fg = c.dim, bg = c.surface })

	hl("HeirlinePosition", { fg = c.black, bg = c.magenta_bright, bold = true })
end

return M
