local palette = require("config.theme.palette")
local p, a = palette.p, palette.a

local M = {}

---@return HighlightGroups
M.get = function()
	return {
		Comment = { fg = p.dim, italic = true },
		Constant = { fg = p.surface.base, bold = true },
		String = { fg = p.surface.variant },
		Character = { fg = p.surface.variant },
		Number = { fg = p.surface.base },
		Boolean = { fg = p.surface.variant, bold = true },
		Float = { fg = p.surface.base },
		Identifier = { fg = p.foreground.variant },
		Function = { fg = p.surface.variant, bold = true },
		Statement = { fg = p.accent.base, bold = true },
		Conditional = { fg = p.accent.base, bold = true },
		Repeat = { fg = p.accent.base, bold = true },
		Label = { fg = p.foreground.base },
		Operator = { fg = p.foreground.base },
		Keyword = { fg = p.accent.base, bold = true },
		Exception = { fg = a.error },
		PreProc = { fg = p.surface.base },
		Include = { fg = p.surface.base, bold = true },
		Define = { fg = p.surface.base },
		Macro = { fg = p.surface.base },
		PreCondit = { fg = p.surface.base },
		Type = { fg = p.surface.base, italic = true },
		Declaration = { fg = p.surface.variant },
		Property = { fg = p.foreground.variant },
		Parameter = { fg = p.surface.base, italic = true },
		StorageClass = { fg = p.surface.base },
		Structure = { fg = p.surface.base },
		Typedef = { fg = p.surface.base },
		Special = { fg = p.surface.base },
		SpecialChar = { fg = p.surface.variant },
		Tag = { fg = p.accent.base },
		Delimiter = { fg = p.dim },
		SpecialComment = { fg = p.dim, bold = true },
		Debug = { fg = a.error },
		Underlined = { underline = true },
		Ignore = { fg = p.dim },
		Error = { fg = a.error, bold = true },
		Todo = { fg = p.background.base, bg = a.warn, bold = true },
		Added = { fg = a.success },
		Changed = { fg = a.warn },
		Removed = { fg = a.error },
		DiffAdd = { fg = a.success, bg = p.background.variant },
		DiffChange = { fg = a.warn, bg = p.background.variant },
		DiffDelete = { fg = a.error, bg = p.background.variant },
		DiffText = { fg = a.warn, bg = p.dim, bold = true },
	}
end

return M
