---@type HighlightModule
local M = {}

---@param p ThemePalette
---@return HighlightGroups
function M.get(p)
	return {
		DiagnosticError = { fg = p.red },
		DiagnosticWarn = { fg = p.amber },
		DiagnosticInfo = { fg = p.cyan },
		DiagnosticHint = { fg = p.olive_bright },
		DiagnosticOk = { fg = p.teal },

		DiagnosticSignError = { fg = p.red },
		DiagnosticSignWarn = { fg = p.amber },
		DiagnosticSignInfo = { fg = p.cyan },
		DiagnosticSignHint = { fg = p.olive_bright },
		DiagnosticSignOk = { fg = p.teal },

		DiagnosticVirtualTextError = { fg = p.red, bg = p.error_bg },
		DiagnosticVirtualTextWarn = { fg = p.amber, bg = p.warn_bg },
		DiagnosticVirtualTextInfo = { fg = p.cyan, bg = p.info_bg },
		DiagnosticVirtualTextHint = { fg = p.olive_bright, bg = p.hint_bg },
		DiagnosticVirtualTextOk = { fg = p.teal, bg = p.hint_bg },

		DiagnosticFloatingError = { fg = p.red },
		DiagnosticFloatingWarn = { fg = p.amber },
		DiagnosticFloatingInfo = { fg = p.cyan },
		DiagnosticFloatingHint = { fg = p.olive_bright },
		DiagnosticFloatingOk = { fg = p.teal },

		DiagnosticUnderlineError = { sp = p.red, undercurl = true },
		DiagnosticUnderlineWarn = { sp = p.amber, undercurl = true },
		DiagnosticUnderlineInfo = { sp = p.cyan, undercurl = true },
		DiagnosticUnderlineHint = { sp = p.olive_bright, undercurl = true },
		DiagnosticUnderlineOk = { sp = p.teal, undercurl = true },

		LspReferenceText = { bg = p.selection },
		LspReferenceRead = { bg = p.selection },
		LspReferenceWrite = { bg = p.selection, bold = true },
		LspReferenceTarget = { fg = p.amber, bold = true },
		LspInlayHint = { fg = p.muted, bg = p.bg_alt },
		LspCodeLens = { fg = p.subtle },
		LspCodeLensSeparator = { fg = p.subtle },
		LspSignatureActiveParameter = { fg = p.bg, bg = p.search_current, bold = true },

		["@lsp.type.class"] = { link = "@type" },
		["@lsp.type.decorator"] = { fg = p.rust },
		["@lsp.type.enum"] = { fg = p.cyan },
		["@lsp.type.enumMember"] = { fg = p.amber },
		["@lsp.type.function"] = { link = "@function" },
		["@lsp.type.interface"] = { fg = p.teal },
		["@lsp.type.keyword"] = { link = "@keyword" },
		["@lsp.type.macro"] = { fg = p.rust },
		["@lsp.type.method"] = { link = "@function.method" },
		["@lsp.type.namespace"] = { fg = p.teal },
		["@lsp.type.parameter"] = { link = "@variable.parameter" },
		["@lsp.type.property"] = { link = "@property" },
		["@lsp.type.string"] = { link = "@string" },
		["@lsp.type.type"] = { link = "@type" },
		["@lsp.type.typeParameter"] = { fg = p.cyan },
		["@lsp.type.variable"] = { link = "@variable" },

		["@lsp.mod.defaultLibrary"] = { fg = p.rust },
		["@lsp.mod.deprecated"] = { strikethrough = true, fg = p.subtle },
		["@lsp.mod.readonly"] = { italic = true },
		["@lsp.mod.static"] = { fg = p.amber },
		["@lsp.mod.async"] = { italic = true },

		["@lsp.typemod.variable.readonly"] = { fg = p.violet, italic = true },
		["@lsp.typemod.function.async"] = { fg = p.amber, italic = true },
	}
end

return M
