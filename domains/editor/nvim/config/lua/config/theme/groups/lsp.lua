---@class HighlightModule
local M = {}

---@param p ThemeColors
---@return HighlightGroups
M.get = function(p)
	local e = p.editor
	local s = p.syntax
	local d = p.diagnostic

	return {
		DiagnosticError = { fg = d.error },
		DiagnosticWarn = { fg = d.warn },
		DiagnosticInfo = { fg = d.info },
		DiagnosticHint = { fg = d.hint },
		DiagnosticOk = { fg = d.ok },

		DiagnosticSignError = { fg = d.error },
		DiagnosticSignWarn = { fg = d.warn },
		DiagnosticSignInfo = { fg = d.info },
		DiagnosticSignHint = { fg = d.hint },
		DiagnosticSignOk = { fg = d.ok },

		DiagnosticVirtualTextError = { fg = d.error, bg = e.surface },
		DiagnosticVirtualTextWarn = { fg = d.warn, bg = e.surface },
		DiagnosticVirtualTextInfo = { fg = d.info, bg = e.surface },
		DiagnosticVirtualTextHint = { fg = d.hint, bg = e.surface },
		DiagnosticVirtualTextOk = { fg = d.ok, bg = e.surface },

		DiagnosticFloatingError = { fg = d.error },
		DiagnosticFloatingWarn = { fg = d.warn },
		DiagnosticFloatingInfo = { fg = d.info },
		DiagnosticFloatingHint = { fg = d.hint },
		DiagnosticFloatingOk = { fg = d.ok },

		DiagnosticUnderlineError = { sp = d.error, underline = true },
		DiagnosticUnderlineWarn = { sp = d.warn, underline = true },
		DiagnosticUnderlineInfo = { sp = d.info, underline = true },
		DiagnosticUnderlineHint = { sp = d.hint, underline = true },
		DiagnosticUnderlineOk = { sp = d.ok, underline = true },
		DiagnosticUnnecessary = { fg = e.comment, italic = true },
		DiagnosticDeprecated = { strikethrough = true },

		LspReferenceText = { bg = e.surface },
		LspReferenceRead = { bg = e.surface },
		LspReferenceWrite = { bg = e.surface },
		LspReferenceTarget = { fg = d.warn, bold = true },
		LspInlayHint = { fg = e.dim },
		LspCodeLens = { fg = e.comment },
		LspCodeLensSeparator = { fg = e.dim },
		LspSignatureActiveParameter = { fg = d.warn, bold = true },

		["@lsp.type.class"] = { link = "@type" },
		["@lsp.type.decorator"] = { fg = s.special },
		["@lsp.type.enum"] = { fg = s.type },
		["@lsp.type.enumMember"] = { fg = s.constant },
		["@lsp.type.function"] = { link = "@function" },
		["@lsp.type.interface"] = { fg = s.type },
		["@lsp.type.keyword"] = { link = "@keyword" },
		["@lsp.type.macro"] = { fg = s.special },
		["@lsp.type.method"] = { link = "@function.method" },
		["@lsp.type.namespace"] = { fg = s.type },
		["@lsp.type.parameter"] = { link = "@variable.parameter" },
		["@lsp.type.property"] = { link = "@property" },
		["@lsp.type.string"] = { link = "@string" },
		["@lsp.type.type"] = { link = "@type" },
		["@lsp.type.typeParameter"] = { fg = s.type },
		["@lsp.type.variable"] = { link = "@variable" },

		["@lsp.mod.defaultLibrary"] = { fg = e.bright },
		["@lsp.mod.deprecated"] = { strikethrough = true, fg = e.comment },
		["@lsp.mod.readonly"] = { italic = true },
		["@lsp.mod.static"] = { fg = s.constant },
		["@lsp.mod.async"] = { italic = true },

		["@lsp.typemod.variable.readonly"] = { fg = s.constant, italic = true },
		["@lsp.typemod.function.async"] = { fg = s["function"], italic = true },
	}
end

return M
