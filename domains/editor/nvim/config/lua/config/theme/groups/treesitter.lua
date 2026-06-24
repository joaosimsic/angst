---@class HighlightModule
local M = {}

---@param p ThemePalette
---@return HighlightGroups
M.get = function(p)
	return {
		["@comment"] = { link = "Comment" },
		["@comment.documentation"] = { fg = p.comment },
		["@comment.error"] = { fg = p.red, bg = p.surface },
		["@comment.note"] = { fg = p.blue, bg = p.surface },
		["@comment.todo"] = { link = "Todo" },
		["@comment.warning"] = { fg = p.yellow, bg = p.surface },

		["@constant"] = { link = "Constant" },
		["@constant.builtin"] = { fg = p.magenta },
		["@constant.macro"] = { fg = p.magenta },
		["@constructor"] = { fg = p.yellow },
		["@module"] = { fg = p.base },
		["@label"] = { link = "Label" },

		["@string"] = { link = "String" },
		["@string.documentation"] = { fg = p.green },
		["@string.escape"] = { fg = p.magenta },
		["@string.regexp"] = { fg = p.cyan },
		["@string.special"] = { fg = p.magenta },
		["@character"] = { link = "Character" },
		["@character.special"] = { fg = p.magenta },
		["@number"] = { link = "Number" },
		["@boolean"] = { link = "Boolean" },
		["@number.float"] = { link = "Float" },

		["@function"] = { link = "Function" },
		["@function.builtin"] = { fg = p.bright },
		["@function.call"] = { fg = p.bright },
		["@function.macro"] = { fg = p.cyan },
		["@function.method"] = { fg = p.bright },
		["@function.method.call"] = { fg = p.bright },

		["@variable"] = { fg = p.base },
		["@variable.builtin"] = { fg = p.red },
		["@variable.parameter"] = { fg = p.base, italic = true },
		["@variable.member"] = { fg = p.base },
		["@property"] = { fg = p.base },
		["@field"] = { fg = p.base },

		["@type"] = { link = "Type" },
		["@type.builtin"] = { fg = p.yellow },
		["@type.definition"] = { link = "Typedef" },
		["@type.qualifier"] = { fg = p.bright, bold = true },
		["@attribute"] = { fg = p.cyan },

		["@keyword"] = { link = "Keyword" },
		["@keyword.conditional"] = { link = "Conditional" },
		["@keyword.coroutine"] = { link = "Keyword" },
		["@keyword.debug"] = { fg = p.red },
		["@keyword.directive"] = { fg = p.cyan },
		["@keyword.directive.define"] = { fg = p.cyan },
		["@keyword.exception"] = { link = "Exception" },
		["@keyword.function"] = { link = "Keyword" },
		["@keyword.import"] = { link = "Include" },
		["@keyword.operator"] = { fg = p.bright },
		["@keyword.repeat"] = { link = "Repeat" },
		["@keyword.return"] = { link = "Keyword" },
		["@keyword.storage"] = { link = "Keyword" },

		["@operator"] = { link = "Operator" },
		["@punctuation.bracket"] = { fg = p.dim },
		["@punctuation.delimiter"] = { fg = p.dim },
		["@punctuation.special"] = { fg = p.cyan },

		["@markup.heading"] = { fg = p.bright, bold = true },
		["@markup.strong"] = { bold = true },
		["@markup.italic"] = { italic = true },
		["@markup.underline"] = { underline = true },
		["@markup.strikethrough"] = { strikethrough = true },
		["@markup.quote"] = { fg = p.comment, italic = true },
		["@markup.math"] = { fg = p.cyan },
		["@markup.raw"] = { fg = p.green },
		["@markup.raw.block"] = { fg = p.green },
		["@markup.link"] = { fg = p.blue, underline = true },
		["@markup.link.label"] = { fg = p.cyan },
		["@markup.link.url"] = { fg = p.blue, underline = true },
		["@markup.list"] = { fg = p.bright },
		["@markup.list.checked"] = { fg = p.green },
		["@markup.list.unchecked"] = { fg = p.dim },

		["@tag"] = { fg = p.bright },
		["@tag.attribute"] = { fg = p.base, italic = true },
		["@tag.delimiter"] = { fg = p.dim },

		["@diff.plus"] = { fg = p.green },
		["@diff.minus"] = { fg = p.red },
		["@diff.delta"] = { fg = p.yellow },
	}
end

return M
