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
		["@comment"] = { link = "Comment" },
		["@comment.documentation"] = { fg = s.comment },
		["@comment.error"] = { fg = d.error, bg = e.surface },
		["@comment.note"] = { fg = d.info, bg = e.surface },
		["@comment.todo"] = { link = "Todo" },
		["@comment.warning"] = { fg = d.warn, bg = e.surface },

		["@constant"] = { link = "Constant" },
		["@constant.builtin"] = { fg = s.constant },
		["@constant.macro"] = { fg = s.constant },
		["@constructor"] = { fg = s.type },
		["@module"] = { fg = s.type },
		["@label"] = { link = "Label" },

		["@string"] = { link = "String" },
		["@string.documentation"] = { fg = s.string },
		["@string.escape"] = { fg = s.constant },
		["@string.regexp"] = { fg = s.special },
		["@string.special"] = { fg = s.constant },
		["@character"] = { link = "Character" },
		["@character.special"] = { fg = s.constant },
		["@number"] = { link = "Number" },
		["@boolean"] = { link = "Boolean" },
		["@number.float"] = { link = "Float" },

		["@function"] = { link = "Function" },
		["@function.builtin"] = { fg = s["function"] },
		["@function.call"] = { fg = s["function"] },
		["@function.macro"] = { link = "Function" },
		["@function.method"] = { fg = s["function"] },
		["@function.method.call"] = { fg = s["function"] },

		["@variable"] = { fg = s.variable },
		["@variable.builtin"] = { fg = d.error },
		["@variable.parameter"] = { fg = s.variable, italic = true },
		["@variable.member"] = { fg = s.variable },
		["@property"] = { fg = s.variable },
		["@field"] = { fg = s.variable },

		["@type"] = { link = "Type" },
		["@type.builtin"] = { fg = s.type },
		["@type.definition"] = { link = "Typedef" },
		["@type.qualifier"] = { fg = s.keyword, bold = true },
		["@attribute"] = { fg = s.preproc },

		["@keyword"] = { link = "Keyword" },
		["@keyword.conditional"] = { link = "Conditional" },
		["@keyword.coroutine"] = { link = "Keyword" },
		["@keyword.debug"] = { fg = d.error },
		["@keyword.directive"] = { fg = s.preproc },
		["@keyword.directive.define"] = { fg = s.preproc },
		["@keyword.exception"] = { link = "Exception" },
		["@keyword.function"] = { link = "Keyword" },
		["@keyword.import"] = { link = "Include" },
		["@keyword.operator"] = { fg = s.operator },
		["@keyword.repeat"] = { link = "Repeat" },
		["@keyword.return"] = { link = "Keyword" },
		["@keyword.storage"] = { link = "Keyword" },

		["@operator"] = { link = "Operator" },
		["@punctuation.bracket"] = { fg = s.punctuation },
		["@punctuation.delimiter"] = { fg = s.punctuation },
		["@punctuation.special"] = { fg = s.special },

		["@markup.heading"] = { fg = e.bright, bold = true },
		["@markup.strong"] = { bold = true },
		["@markup.italic"] = { italic = true },
		["@markup.underline"] = { underline = true },
		["@markup.strikethrough"] = { strikethrough = true },
		["@markup.quote"] = { fg = s.comment, italic = true },
		["@markup.math"] = { fg = s.special },
		["@markup.raw"] = { fg = s.string },
		["@markup.raw.block"] = { fg = s.string },
		["@markup.link"] = { fg = d.hint, underline = true },
		["@markup.link.label"] = { fg = d.info },
		["@markup.link.url"] = { fg = d.hint, underline = true },
		["@markup.list"] = { fg = e.bright },
		["@markup.list.checked"] = { fg = d.ok },
		["@markup.list.unchecked"] = { fg = e.dim },

		["@tag"] = { fg = s.tag },
		["@tag.attribute"] = { fg = s.variable, italic = true },
		["@tag.delimiter"] = { fg = e.dim },

		["@diff.plus"] = { fg = diff.add },
		["@diff.minus"] = { fg = diff.delete },
		["@diff.delta"] = { fg = diff.change },
	}
end

return M
