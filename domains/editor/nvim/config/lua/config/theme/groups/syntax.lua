---@class HighlightModule
local M = {}

---@param p ThemePalette
---@return HighlightGroups
M.get = function(p)
	return {
		Comment = { fg = p.comment, italic = true },
		Constant = { fg = p.bright },
		String = { fg = p.green },
		Character = { fg = p.green },
		Number = { fg = p.magenta },
		Boolean = { fg = p.magenta },
		Float = { fg = p.magenta },
		Identifier = { fg = p.base },
		Function = { fg = p.bright },
		Statement = { fg = p.bright, bold = true },
		Conditional = { fg = p.bright, bold = true },
		Repeat = { fg = p.bright, bold = true },
		Label = { fg = p.cyan },
		Operator = { fg = p.base },
		Keyword = { fg = p.bright, bold = true },
		Exception = { fg = p.red },
		PreProc = { fg = p.cyan },
		Include = { fg = p.cyan },
		Define = { fg = p.cyan },
		Macro = { fg = p.cyan },
		PreCondit = { fg = p.cyan },
		Type = { fg = p.yellow },
		StorageClass = { fg = p.yellow },
		Structure = { fg = p.yellow },
		Typedef = { fg = p.yellow },
		Special = { fg = p.bright },
		SpecialChar = { fg = p.cyan },
		Tag = { fg = p.bright },
		Delimiter = { fg = p.base },
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
