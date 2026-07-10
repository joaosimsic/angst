local palette = require("config.theme.palette").get()
local p = palette.palette
local a = palette.ansi

local M = {}

---@return HighlightGroups
M.get = function()
	return {
		Comment = { fg = p.dim, italic = true },
		Constant = { fg = p.accent.variant },
		String = { fg = p.foreground.variant },
		Character = { fg = p.foreground.variant },
		Number = { fg = p.accent.base },
		Boolean = { fg = p.accent.variant },
		Float = { fg = p.accent.base },
		Identifier = { fg = p.foreground.base },
		Function = { fg = p.foreground.base },
		Statement = { fg = p.accent.base, bold = true },
		Conditional = { fg = p.accent.base, bold = true },
		Repeat = { fg = p.accent.base, bold = true },
		Label = { fg = p.foreground.base },
		Operator = { fg = p.accent.base },
		Keyword = { fg = p.accent.base, bold = true },
		Exception = { fg = a.error },
		PreProc = { fg = p.surface.base },
		Include = { fg = p.surface.base },
		Define = { fg = p.surface.base },
		Macro = { fg = p.surface.base },
		PreCondit = { fg = p.surface.base },
		Type = { fg = p.surface.base },
		StorageClass = { fg = p.surface.base },
		Structure = { fg = p.surface.base },
		Typedef = { fg = p.surface.base },
		Special = { fg = p.foreground.base },
		SpecialChar = { fg = p.accent.variant },
		Tag = { fg = p.accent.base },
		Delimiter = { fg = p.accent.base },
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
