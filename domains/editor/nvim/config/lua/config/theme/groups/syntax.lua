---@class HighlightModule
local M = {}

---@param p ThemePalette
---@return HighlightGroups
M.get = function(p)
	return {
		Comment = { fg = p.comment, italic = true },
		Constant = { fg = p.magenta },
		String = { fg = p.green },
		Character = { fg = p.green },
		Number = { fg = p.magenta },
		Boolean = { fg = p.magenta },
		Float = { fg = p.magenta },
		Identifier = { fg = p.accent },
		Function = { fg = p.blue_bright },
		Statement = { fg = p.bright, bold = true },
		Conditional = { fg = p.magenta, bold = true },
		Repeat = { fg = p.magenta, bold = true },
		Label = { fg = p.cyan },
		Operator = { fg = p.subtle },
		Keyword = { fg = p.yellow_bright, bold = true },
		Exception = { fg = p.red },
		PreProc = { fg = p.blue },
		Include = { fg = p.blue },
		Define = { fg = p.blue },
		Macro = { fg = p.blue },
		PreCondit = { fg = p.blue },
		Type = { fg = p.accent },
		StorageClass = { fg = p.yellow },
		Structure = { fg = p.yellow },
		Typedef = { fg = p.yellow },
		Special = { fg = p.cyan },
		SpecialChar = { fg = p.magenta },
		Tag = { fg = p.yellow },
		Delimiter = { fg = p.dim },
		SpecialComment = { fg = p.comment, bold = true },
		Debug = { fg = p.red },
		Underlined = { underline = true },
		Ignore = { fg = p.dim },
		Error = { fg = p.red, bold = true },
		Todo = { fg = p.black, bg = p.yellow, bold = true },
		Added = { fg = p.green },
		Changed = { fg = p.yellow },
		Removed = { fg = p.red },
		DiffAdd = { fg = p.green, bg = p.surface },
		DiffChange = { fg = p.yellow, bg = p.surface },
		DiffDelete = { fg = p.red, bg = p.surface },
		DiffText = { fg = p.yellow, bg = p.dim, bold = true },
	}
end

return M
