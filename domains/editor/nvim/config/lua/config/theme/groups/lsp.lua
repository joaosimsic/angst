---@class HighlightModule
local M = {}

---@param p ThemePalette
---@return HighlightGroups
M.get = function(p)
	return {
		DiagnosticError = { fg = p.red },
		DiagnosticWarn = { fg = p.yellow },
		DiagnosticInfo = { fg = p.blue },
		DiagnosticHint = { fg = p.cyan },
		DiagnosticOk = { fg = p.green },

		DiagnosticSignError = { fg = p.red },
		DiagnosticSignWarn = { fg = p.yellow },
		DiagnosticSignInfo = { fg = p.blue },
		DiagnosticSignHint = { fg = p.cyan },
		DiagnosticSignOk = { fg = p.green },

		DiagnosticVirtualTextError = { fg = p.red, bg = p.surface },
		DiagnosticVirtualTextWarn = { fg = p.yellow, bg = p.surface },
		DiagnosticVirtualTextInfo = { fg = p.blue, bg = p.surface },
		DiagnosticVirtualTextHint = { fg = p.cyan, bg = p.surface },
		DiagnosticVirtualTextOk = { fg = p.green, bg = p.surface },

		DiagnosticFloatingError = { fg = p.red },
		DiagnosticFloatingWarn = { fg = p.yellow },
		DiagnosticFloatingInfo = { fg = p.blue },
		DiagnosticFloatingHint = { fg = p.cyan },
		DiagnosticFloatingOk = { fg = p.green },

		DiagnosticUnderlineError = { sp = p.red, undercurl = true },
		DiagnosticUnderlineWarn = { sp = p.yellow, undercurl = true },
		DiagnosticUnderlineInfo = { sp = p.blue, undercurl = true },
		DiagnosticUnderlineHint = { sp = p.cyan, undercurl = true },
		DiagnosticUnderlineOk = { sp = p.green, undercurl = true },
		DiagnosticUnnecessary = { fg = p.comment, italic = true },
		DiagnosticDeprecated = { strikethrough = true },

		LspReferenceText = { bg = p.surface },
		LspReferenceRead = { bg = p.surface },
		LspReferenceWrite = { bg = p.surface },
		LspReferenceTarget = { fg = p.yellow, bold = true },
		LspInlayHint = { link = "Comment" },
		LspCodeLens = { fg = p.comment },
		LspCodeLensSeparator = { fg = p.dim },
		LspSignatureActiveParameter = { fg = p.yellow, bold = true },

		["@lsp.type.class"] = { link = "@type" },
		["@lsp.type.decorator"] = { fg = p.cyan },
		["@lsp.type.enum"] = { fg = p.yellow },
		["@lsp.type.enumMember"] = { fg = p.bright },
		["@lsp.type.function"] = { link = "@function" },
		["@lsp.type.interface"] = { fg = p.yellow },
		["@lsp.type.keyword"] = { link = "@keyword" },
		["@lsp.type.macro"] = { fg = p.cyan },
		["@lsp.type.method"] = { link = "@function.method" },
		["@lsp.type.namespace"] = { fg = p.base },
		["@lsp.type.parameter"] = { link = "@variable.parameter" },
		["@lsp.type.property"] = { link = "@property" },
		["@lsp.type.string"] = { link = "@string" },
		["@lsp.type.type"] = { link = "@type" },
		["@lsp.type.typeParameter"] = { fg = p.yellow },
		["@lsp.type.variable"] = { link = "@variable" },

		["@lsp.mod.defaultLibrary"] = { fg = p.bright },
		["@lsp.mod.deprecated"] = { strikethrough = true, fg = p.comment },
		["@lsp.mod.readonly"] = { italic = true },
		["@lsp.mod.static"] = { fg = p.yellow },
		["@lsp.mod.async"] = { italic = true },

		["@lsp.typemod.variable.readonly"] = { fg = p.magenta, italic = true },
		["@lsp.typemod.function.async"] = { fg = p.yellow, italic = true },
	}
end

return M
