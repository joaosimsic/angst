local M = {}

---@return HighlightGroups
M.get = function()
	return {
		DiagnosticError = { link = "Error" },
		DiagnosticWarn = { link = "WarningMsg" },
		DiagnosticInfo = { link = "Question" },
		DiagnosticHint = { link = "Comment" },
		DiagnosticOk = { link = "Added" },

		DiagnosticSignError = { link = "DiagnosticError" },
		DiagnosticSignWarn = { link = "DiagnosticWarn" },
		DiagnosticSignInfo = { link = "DiagnosticInfo" },
		DiagnosticSignHint = { link = "DiagnosticHint" },
		DiagnosticSignOk = { link = "DiagnosticOk" },

		DiagnosticVirtualTextError = { link = "DiagnosticError" },
		DiagnosticVirtualTextWarn = { link = "DiagnosticWarn" },
		DiagnosticVirtualTextInfo = { link = "DiagnosticInfo" },
		DiagnosticVirtualTextHint = { link = "DiagnosticHint" },
		DiagnosticVirtualTextOk = { link = "DiagnosticOk" },

		DiagnosticFloatingError = { link = "DiagnosticError" },
		DiagnosticFloatingWarn = { link = "DiagnosticWarn" },
		DiagnosticFloatingInfo = { link = "DiagnosticInfo" },
		DiagnosticFloatingHint = { link = "DiagnosticHint" },
		DiagnosticFloatingOk = { link = "DiagnosticOk" },

		DiagnosticUnderlineError = { link = "SpellBad" },
		DiagnosticUnderlineWarn = { link = "SpellCap" },
		DiagnosticUnderlineInfo = { link = "SpellLocal" },
		DiagnosticUnderlineHint = { link = "SpellRare" },
		DiagnosticUnderlineOk = { link = "Underlined" },
		DiagnosticUnnecessary = { link = "Comment" },
		DiagnosticDeprecated = { link = "@markup.strikethrough" },

		LspReferenceText = { link = "CursorLine" },
		LspReferenceRead = { link = "CursorLine" },
		LspReferenceWrite = { link = "CursorLine" },
		LspReferenceTarget = { link = "MatchParen" },
		LspInlayHint = { link = "NonText" },
		LspCodeLens = { link = "NonText" },
		LspCodeLensSeparator = { link = "NonText" },
		LspSignatureActiveParameter = { link = "MatchParen" },

		["@lsp.type.class"] = { link = "@type" },
		["@lsp.type.decorator"] = { link = "@attribute" },
		["@lsp.type.enum"] = { link = "@type" },
		["@lsp.type.enumMember"] = { link = "@constant" },
		["@lsp.type.function"] = { link = "@function" },
		["@lsp.type.interface"] = { link = "@type" },
		["@lsp.type.keyword"] = { link = "@keyword" },
		["@lsp.type.macro"] = { link = "@function.macro" },
		["@lsp.type.method"] = { link = "@function.method" },
		["@lsp.type.namespace"] = { link = "@module" },
		["@lsp.type.parameter"] = { link = "@variable.parameter" },
		["@lsp.type.property"] = { link = "@property" },
		["@lsp.type.string"] = { link = "@string" },
		["@lsp.type.type"] = { link = "@type" },
		["@lsp.type.typeParameter"] = { link = "@type.definition" },
		["@lsp.type.variable"] = { link = "@variable" },

		["@lsp.mod.defaultLibrary"] = { link = "@type.builtin" },
		["@lsp.mod.deprecated"] = { link = "@markup.strikethrough" },
		["@lsp.mod.readonly"] = { link = "@markup.italic" },
		["@lsp.mod.static"] = { link = "@constant" },
		["@lsp.mod.declaration"] = { link = "Declaration" },

		["@lsp.typemod.variable.readonly"] = { link = "@constant" },
		["@lsp.typemod.function.async"] = { link = "@function" },
		["@lsp.typemod.property.declaration"] = { link = "Declaration" },
	}
end

return M
