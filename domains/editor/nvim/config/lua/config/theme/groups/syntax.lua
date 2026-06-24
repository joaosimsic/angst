---@type HighlightModule
local M = {}

---@param p ThemePalette
---@return HighlightGroups
function M.get(p)
	return {
		Comment = vim.tbl_extend("force", { fg = p.muted }, opts.styles.comments or {}),
		Constant = { fg = p.sand },
		String = vim.tbl_extend("force", { fg = p.cyan }, opts.styles.strings or {}),
		Character = { fg = p.cyan },
		Number = { fg = p.sand },
		Boolean = { fg = p.violet },
		Float = { fg = p.sand },
		Identifier = vim.tbl_extend("force", { fg = p.fg_alt }, opts.styles.variables or {}),
		Function = vim.tbl_extend("force", { fg = p.rust }, opts.styles.functions or {}),
		Statement = { fg = p.olive },
		Conditional = { fg = p.olive },
		Repeat = { fg = p.olive },
		Label = { fg = p.olive },
		Operator = { fg = p.fg_alt },
		Keyword = vim.tbl_extend("force", { fg = p.olive }, opts.styles.keywords or {}),
		Exception = { fg = p.rust },
		PreProc = { fg = p.rust },
		Include = { fg = p.rust },
		Define = { fg = p.rust },
		Macro = { fg = p.rust },
		PreCondit = { fg = p.rust },
		Type = { fg = p.cyan },
		StorageClass = { fg = p.cyan },
		Structure = { fg = p.cyan },
		Typedef = { fg = p.cyan },
		Special = { fg = p.rust },
		SpecialChar = { fg = p.cyan },
		Tag = { fg = p.teal },
		Delimiter = { fg = p.subtle },
		Debug = { fg = p.red },
		Underlined = { fg = p.cyan, underline = true },
		Ignore = { fg = p.subtle },
		Error = { fg = p.red, bg = p.error_bg, bold = true },
		Todo = { fg = p.bg, bg = p.search_current, bold = true },
		Added = { fg = p.olive_bright },
		Changed = { fg = p.amber },
		Removed = { fg = p.red },
		DiffAdd = { fg = p.olive_bright, bg = p.diff_add },
		DiffChange = { fg = p.amber, bg = p.diff_change },
		DiffDelete = { fg = p.red, bg = p.diff_delete },
		DiffText = { fg = p.fg, bg = p.diff_text, bold = true },
	}
end

return M
