local M = {}

function M.setup(c)
	-- Clear out previous highlight definitions
	vim.cmd("hi clear")
	if vim.fn.exists("syntax_on") then
		vim.cmd("syntax reset")
	end

	vim.g.colors_name = "angst"
	local hl = vim.api.nvim_set_hl

	-- =========================================================================
	-- 1. Base NATIVE Highlights (Groups that define a unique combination)
	-- =========================================================================
	local base_highlights = {
		-- Editor Interface Layout
		Normal = { fg = c.base, bg = c.black },
		FloatBorder = { fg = c.dim, bg = c.black },
		FloatTitle = { fg = c.bright, bg = c.black, bold = true },
		Cursor = { fg = c.black, bg = c.base },
		CursorLine = { bg = c.surface },
		CursorLineNr = { fg = c.bright, bold = true },
		LineNr = { fg = c.dim },
		StatusLine = { fg = c.base, bg = c.surface },
		StatusLineNC = { fg = c.dim, bg = c.black },
		TabLineSel = { fg = c.bright, bg = c.surface, bold = true },
		Pmenu = { fg = c.base, bg = c.surface },
		PmenuSel = { fg = c.black, bg = c.base },
		Visual = { bg = c.dim },

		-- Search & Messaging Feedback
		Search = { fg = c.black, bg = c.yellow },
		IncSearch = { fg = c.black, bg = c.yellow_bright },
		CurSearch = { fg = c.black, bg = c.yellow_bright, bold = true },
		Substitute = { fg = c.black, bg = c.red },
		MatchParen = { fg = c.yellow_bright, bold = true, underline = true },
		Folded = { fg = c.comment, bg = c.surface },
		Title = { fg = c.bright, bold = true },
		ModeMsg = { fg = c.base, bold = true },
		ErrorMsg = { fg = c.red, bold = true },

		-- Native Vim Standard Syntax Fallbacks
		Comment = { fg = c.comment, italic = true },
		Constant = { fg = c.bright },
		String = { fg = c.green },
		Number = { fg = c.magenta },
		Identifier = { fg = c.base },
		Function = { fg = c.bright },
		Statement = { fg = c.bright, bold = true },
		Label = { fg = c.cyan },
		PreProc = { fg = c.cyan },
		Type = { fg = c.yellow },
		Special = { fg = c.bright },
		Underlined = { underline = true },

		-- Native Diagnostic Engine
		DiagnosticError = { fg = c.red },
		DiagnosticWarn = { fg = c.yellow },
		DiagnosticInfo = { fg = c.blue },
		DiagnosticHint = { fg = c.cyan },
		DiagnosticOk = { fg = c.green },

		-- Native Diagnostics Virtual Text
		DiagnosticVirtualTextError = { fg = c.red, bg = c.surface },
		DiagnosticVirtualTextWarn = { fg = c.yellow, bg = c.surface },
		DiagnosticVirtualTextInfo = { fg = c.blue, bg = c.surface },
		DiagnosticVirtualTextHint = { fg = c.cyan, bg = c.surface },
		DiagnosticVirtualTextOk = { fg = c.green, bg = c.surface },

		-- Native Diagnostics Underlines
		DiagnosticUnderlineError = { sp = c.red, undercurl = true },
		DiagnosticUnderlineWarn = { sp = c.yellow, undercurl = true },
		DiagnosticUnderlineInfo = { sp = c.blue, undercurl = true },
		DiagnosticUnderlineHint = { sp = c.cyan, undercurl = true },
		DiagnosticUnderlineOk = { sp = c.green, undercurl = true },

		-- Spellchecking
		SpellBad = { sp = c.red, undercurl = true },
		SpellCap = { sp = c.yellow, undercurl = true },
		SpellLocal = { sp = c.cyan, undercurl = true },
		SpellRare = { sp = c.magenta, undercurl = true },

		-- Native Diff Engine
		DiffAdd = { fg = c.green, bg = c.surface },
		DiffChange = { fg = c.yellow, bg = c.surface },
		DiffDelete = { fg = c.red, bg = c.surface },
		DiffText = { fg = c.yellow, bg = c.dim, bold = true },

		-- Treesitter Base Group Overrides
		["@variable.builtin"] = { fg = c.red },
		["@variable.parameter"] = { fg = c.base, italic = true },
		["@type.qualifier"] = { fg = c.bright, bold = true },
		["@comment.error"] = { fg = c.red, bg = c.surface },
		["@comment.warning"] = { fg = c.yellow, bg = c.surface },
		["@comment.todo"] = { fg = c.black, bg = c.yellow, bold = true },
		["@comment.note"] = { fg = c.blue, bg = c.surface },
		["@markup.strong"] = { bold = true },
		["@markup.italic"] = { italic = true },
		["@markup.strikethrough"] = { strikethrough = true },
		["@markup.underline"] = { underline = true },
		["@tag.attribute"] = { fg = c.base, italic = true },

		-- Built-in LSP Engine Extensions
		LspReferenceText = { bg = c.surface },
		LspSignatureActiveParameter = { fg = c.yellow, bold = true },

		-- Checkhealth
		healthError = { fg = c.red },
		healthSuccess = { fg = c.green },
		healthWarning = { fg = c.yellow },
	}

	-- Apply base unique rules
	for group, styles in pairs(base_highlights) do
		hl(0, group, styles)
	end

	-- =========================================================================
	-- 2. Inherit Linking Maps (Groups copying an existing anchor rule)
	-- =========================================================================
	local inheritance_links = {
		-- Base UI Redundancy Elimination
		NormalNC = "Normal",
		NormalFloat = "Normal",
		SignColumn = "Normal",
		TabLineFill = "NormalNC",
		CursorColumn = "CursorLine",
		ColorColumn = "CursorLine",
		VertSplit = "LineNr",
		WinSeparator = "LineNr",
		FoldColumn = "LineNr",
		NonText = "LineNr",
		SpecialKey = "LineNr",
		Whitespace = "LineNr",
		EndOfBuffer = "Normal",
		TabLine = "StatusLineNC",
		PmenuSbar = "Pmenu",
		PmenuThumb = "LineNr",
		VisualNOS = "Visual",

		-- Messaging Fallbacks
		Directory = "Type",
		Question = "MoreMsg",
		MoreMsg = "String",
		WarningMsg = "Type",

		-- Code Syntax Redundancy Elimination
		Character = "String",
		Boolean = "Number",
		Float = "Number",
		Conditional = "Statement",
		Repeat = "Statement",
		Keyword = "Statement",
		Exception = "ErrorMsg",
		Include = "PreProc",
		Define = "PreProc",
		Macro = "PreProc",
		PreCondit = "PreProc",
		StorageClass = "Type",
		Structure = "Type",
		Typedef = "Type",
		SpecialChar = "Number",
		Tag = "Statement",
		Delimiter = "Identifier",
		SpecialComment = "Comment",
		Debug = "ErrorMsg",
		Ignore = "LineNr",
		Error = "ErrorMsg",
		Todo = "@comment.todo",

		-- Treesitter Root Inheritance Links
		["@variable"] = "Identifier",
		["@variable.member"] = "Identifier",
		["@constant"] = "Constant",
		["@constant.builtin"] = "Number",
		["@constant.macro"] = "Number",
		["@module"] = "Identifier",
		["@label"] = "Label",
		["@string"] = "String",
		["@string.documentation"] = "String",
		["@string.regexp"] = "PreProc",
		["@string.escape"] = "Number",
		["@string.special"] = "Number",
		["@character"] = "String",
		["@character.special"] = "Number",
		["@boolean"] = "Number",
		["@number"] = "Number",
		["@number.float"] = "Number",
		["@type"] = "Type",
		["@type.builtin"] = "Type",
		["@type.definition"] = "Type",
		["@attribute"] = "PreProc",
		["@property"] = "Identifier",
		["@function"] = "Function",
		["@function.builtin"] = "Function",
		["@function.call"] = "Function",
		["@function.macro"] = "PreProc",
		["@function.method"] = "Function",
		["@function.method.call"] = "Function",
		["@constructor"] = "Type",
		["@operator"] = "Identifier",
		["@keyword"] = "Statement",
		["@keyword.coroutine"] = "Statement",
		["@keyword.function"] = "Statement",
		["@keyword.operator"] = "Statement",
		["@keyword.import"] = "PreProc",
		["@keyword.storage"] = "Statement",
		["@keyword.repeat"] = "Statement",
		["@keyword.return"] = "Statement",
		["@keyword.debug"] = "ErrorMsg",
		["@keyword.exception"] = "ErrorMsg",
		["@keyword.conditional"] = "Statement",
		["@keyword.directive"] = "PreProc",
		["@keyword.directive.define"] = "PreProc",
		["@punctuation.delimiter"] = "LineNr",
		["@punctuation.bracket"] = "LineNr",
		["@punctuation.special"] = "PreProc",
		["@comment"] = "Comment",
		["@comment.documentation"] = "Comment",
		["@markup.heading"] = "Title",
		["@markup.quote"] = "Comment",
		["@markup.math"] = "PreProc",
		["@markup.link"] = "Directory",
		["@markup.link.label"] = "PreProc",
		["@markup.link.url"] = "Directory",
		["@markup.raw"] = "String",
		["@markup.list"] = "Title",
		["@markup.list.checked"] = "String",
		["@markup.list.unchecked"] = "LineNr",
		["@diff.plus"] = "String",
		["@diff.minus"] = "ErrorMsg",
		["@diff.delta"] = "Type",
		["@tag"] = "Title",
		["@tag.delimiter"] = "LineNr",

		-- Built-in Diagnostics Floats & Signs Inheritance
		DiagnosticFloatingError = "DiagnosticError",
		DiagnosticFloatingWarn = "DiagnosticWarn",
		DiagnosticFloatingInfo = "DiagnosticInfo",
		DiagnosticFloatingHint = "DiagnosticHint",
		DiagnosticFloatingOk = "DiagnosticOk",
		DiagnosticSignError = "DiagnosticError",
		DiagnosticSignWarn = "DiagnosticWarn",
		DiagnosticSignInfo = "DiagnosticInfo",
		DiagnosticSignHint = "DiagnosticHint",
		DiagnosticSignOk = "DiagnosticOk",
		DiagnosticUnnecessary = "Comment",
		DiagnosticDeprecated = "@markup.strikethrough",

		-- Built-in LSP References Inheritance
		LspReferenceRead = "LspReferenceText",
		LspReferenceWrite = "LspReferenceText",
		LspCodeLens = "Comment",
		LspCodeLensSeparator = "LineNr",
		LspInlayHint = "Comment",

		-- Native Unified Diff Patch Fallbacks
		diffAdded = "String",
		diffRemoved = "ErrorMsg",
		diffChanged = "Type",
		diffFile = "Title",
		diffNewFile = "String",
		diffOldFile = "ErrorMsg",
		diffLine = "PreProc",
		diffIndexLine = "Number",
	}

	-- Apply the linking structure dynamically
	for source_group, target_anchor in pairs(inheritance_links) do
		hl(0, source_group, { link = target_anchor })
	end
end

return M
