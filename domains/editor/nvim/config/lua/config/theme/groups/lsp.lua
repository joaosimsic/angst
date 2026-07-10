local palette = require("config.theme.palette").get()
local p = palette.palette
local a = palette.ansi

local M = {}

---@return HighlightGroups
M.get = function()
	return {
		DiagnosticError = { fg = a.error },
		DiagnosticWarn = { fg = a.warn },
		DiagnosticInfo = { fg = a.info },
		DiagnosticHint = { fg = p.surface.base },
		DiagnosticOk = { fg = a.success },

		DiagnosticSignError = { fg = a.error },
		DiagnosticSignWarn = { fg = a.warn },
		DiagnosticSignInfo = { fg = a.info },
		DiagnosticSignHint = { fg = p.surface.base },
		DiagnosticSignOk = { fg = a.success },

		DiagnosticVirtualTextError = { fg = a.error, bg = p.background.variant },
		DiagnosticVirtualTextWarn = { fg = a.warn, bg = p.background.variant },
		DiagnosticVirtualTextInfo = { fg = a.info, bg = p.background.variant },
		DiagnosticVirtualTextHint = { fg = p.surface.base, bg = p.background.variant },
		DiagnosticVirtualTextOk = { fg = a.success, bg = p.background.variant },

		DiagnosticFloatingError = { fg = a.error },
		DiagnosticFloatingWarn = { fg = a.warn },
		DiagnosticFloatingInfo = { fg = a.info },
		DiagnosticFloatingHint = { fg = p.surface.base },
		DiagnosticFloatingOk = { fg = a.success },

		DiagnosticUnderlineError = { sp = a.error, underline = true },
		DiagnosticUnderlineWarn = { sp = a.warn, underline = true },
		DiagnosticUnderlineInfo = { sp = a.info, underline = true },
		DiagnosticUnderlineHint = { sp = p.surface.base, underline = true },
		DiagnosticUnderlineOk = { sp = a.success, underline = true },
		DiagnosticUnnecessary = { fg = p.dim, italic = true },
		DiagnosticDeprecated = { strikethrough = true },

		LspReferenceText = { bg = p.background.variant },
		LspReferenceRead = { bg = p.background.variant },
		LspReferenceWrite = { bg = p.background.variant },
		LspReferenceTarget = { fg = a.warn, bold = true },
		LspInlayHint = { fg = p.dim },
		LspCodeLens = { fg = p.dim },
		LspCodeLensSeparator = { fg = p.dim },
		LspSignatureActiveParameter = { fg = a.warn, bold = true },

		["@lsp.type.class"] = { link = "@type" },
		["@lsp.type.decorator"] = { fg = p.foreground.base },
		["@lsp.type.enum"] = { fg = p.surface.base },
		["@lsp.type.enumMember"] = { fg = p.accent.variant },
		["@lsp.type.function"] = { link = "@function" },
		["@lsp.type.interface"] = { fg = p.surface.base },
		["@lsp.type.keyword"] = { link = "@keyword" },
		["@lsp.type.macro"] = { fg = p.foreground.base },
		["@lsp.type.method"] = { link = "@function.method" },
		["@lsp.type.namespace"] = { fg = p.surface.base },
		["@lsp.type.parameter"] = { link = "@variable.parameter" },
		["@lsp.type.property"] = { link = "@property" },
		["@lsp.type.string"] = { link = "@string" },
		["@lsp.type.type"] = { link = "@type" },
		["@lsp.type.typeParameter"] = { fg = p.surface.base },
		["@lsp.type.variable"] = { link = "@variable" },

		["@lsp.mod.defaultLibrary"] = { fg = p.foreground.variant },
		["@lsp.mod.deprecated"] = { strikethrough = true, fg = p.dim },
		["@lsp.mod.readonly"] = { italic = true },
		["@lsp.mod.static"] = { fg = p.accent.variant },
		["@lsp.mod.async"] = { italic = true },

		["@lsp.typemod.variable.readonly"] = { fg = p.accent.variant, italic = true },
		["@lsp.typemod.function.async"] = { fg = p.foreground.base, italic = true },
	}
end

return M
