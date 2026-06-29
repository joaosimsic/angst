---@class HighlightModule
local M = {}

---@param p ThemeColors
---@return HighlightGroups
M.get = function(p)
	local e = p.editor
	local s = p.syntax
	local d = p.diagnostic
	local diff = p.diff

	return {
		Comment = { fg = s.comment, italic = true },
		Constant = { fg = s.constant },
		String = { fg = s.string },
		Character = { fg = s.string },
		Number = { fg = s.number },
		Boolean = { fg = s.constant },
		Float = { fg = s.number },
		Identifier = { fg = s.variable },
		Function = { fg = s["function"] },
		Statement = { fg = s.keyword, bold = true },
		Conditional = { fg = s.keyword, bold = true },
		Repeat = { fg = s.keyword, bold = true },
		Label = { fg = s.label },
		Operator = { fg = s.operator },
		Keyword = { fg = s.keyword, bold = true },
		Exception = { fg = d.error },
		PreProc = { fg = s.preproc },
		Include = { fg = s.preproc },
		Define = { fg = s.preproc },
		Macro = { fg = s.preproc },
		PreCondit = { fg = s.preproc },
		Type = { fg = s.type },
		StorageClass = { fg = s.type },
		Structure = { fg = s.type },
		Typedef = { fg = s.type },
		Special = { fg = s.special },
		SpecialChar = { fg = s.constant },
		Tag = { fg = s.tag },
		Delimiter = { fg = s.punctuation },
		SpecialComment = { fg = s.comment, bold = true },
		Debug = { fg = d.error },
		Underlined = { underline = true },
		Ignore = { fg = e.dim },
		Error = { fg = d.error, bold = true },
		Todo = { fg = e.bg, bg = d.warn, bold = true },
		Added = { fg = diff.add },
		Changed = { fg = diff.change },
		Removed = { fg = diff.delete },
		DiffAdd = { fg = diff.add, bg = e.surface },
		DiffChange = { fg = diff.change, bg = e.surface },
		DiffDelete = { fg = diff.delete, bg = e.surface },
		DiffText = { fg = diff.text, bg = e.dim, bold = true },
	}
end

return M
