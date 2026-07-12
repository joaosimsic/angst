local M = {}

---@return HighlightGroups
M.get = function()
	return {
		["@comment"] = { link = "Comment" },
		["@comment.documentation"] = { link = "Comment" },
		["@comment.error"] = { link = "Error" },
		["@comment.note"] = { link = "Comment" },
		["@comment.todo"] = { link = "Todo" },
		["@comment.warning"] = { link = "Changed" },

		["@constant"] = { link = "Constant" },
		["@constant.builtin"] = { link = "Constant" },
		["@constant.macro"] = { link = "Constant" },
		["@constructor"] = { link = "Type" },
		["@module"] = { link = "Include" },
		["@label"] = { link = "Label" },

		["@string"] = { link = "String" },
		["@string.documentation"] = { link = "String" },
		["@string.escape"] = { link = "SpecialChar" },
		["@string.regexp"] = { link = "Special" },
		["@string.special"] = { link = "SpecialChar" },
		["@character"] = { link = "Character" },
		["@character.special"] = { link = "SpecialChar" },
		["@number"] = { link = "Number" },
		["@boolean"] = { link = "Boolean" },
		["@number.float"] = { link = "Float" },

		["@function"] = { link = "Function" },
		["@function.builtin"] = { link = "Function" },
		["@function.call"] = { link = "Function" },
		["@function.macro"] = { link = "Function" },
		["@function.method"] = { link = "Function" },
		["@function.method.call"] = { link = "Function" },

		["@variable"] = { link = "Identifier" },
		["@variable.builtin"] = { link = "Constant" },
		["@variable.parameter"] = { link = "Parameter" },
		["@variable.member"] = { link = "Identifier" },
		["@property"] = { link = "Property" },
		["@field"] = { link = "Identifier" },

		["@type"] = { link = "Type" },
		["@type.builtin"] = { link = "Type" },
		["@type.definition"] = { link = "Typedef" },
		["@type.qualifier"] = { link = "Keyword" },
		["@attribute"] = { link = "PreProc" },

		["@keyword"] = { link = "Keyword" },
		["@keyword.conditional"] = { link = "Conditional" },
		["@keyword.coroutine"] = { link = "Keyword" },
		["@keyword.debug"] = { link = "Debug" },
		["@keyword.directive"] = { link = "PreProc" },
		["@keyword.directive.define"] = { link = "Define" },
		["@keyword.exception"] = { link = "Exception" },
		["@keyword.function"] = { link = "Keyword" },
		["@keyword.import"] = { link = "Include" },
		["@keyword.operator"] = { link = "Operator" },
		["@keyword.repeat"] = { link = "Repeat" },
		["@keyword.return"] = { link = "Keyword" },
		["@keyword.storage"] = { link = "Keyword" },

		["@conditional"] = { link = "Conditional" },

		["@operator"] = { link = "Operator" },
		["@punctuation.bracket"] = { link = "Delimiter" },
		["@punctuation.delimiter"] = { link = "Delimiter" },
		["@punctuation.special"] = { link = "Special" },

		["@markup.heading"] = { link = "Keyword" },
		["@markup.strong"] = { link = "Keyword" },
		["@markup.italic"] = { link = "Comment" },
		["@markup.underline"] = { link = "Underlined" },
		["@markup.strikethrough"] = { link = "Underlined" },
		["@markup.quote"] = { link = "Comment" },
		["@markup.math"] = { link = "Special" },
		["@markup.raw"] = { link = "String" },
		["@markup.raw.block"] = { link = "String" },
		["@markup.link"] = { link = "Underlined" },
		["@markup.link.label"] = { link = "Identifier" },
		["@markup.link.url"] = { link = "Underlined" },
		["@markup.list"] = { link = "Delimiter" },
		["@markup.list.checked"] = { link = "Added" },
		["@markup.list.unchecked"] = { link = "Ignore" },

		["@tag"] = { link = "Tag" },
		["@tag.attribute"] = { link = "Identifier" },
		["@tag.delimiter"] = { link = "Ignore" },

		["@diff.plus"] = { link = "Added" },
		["@diff.minus"] = { link = "Removed" },
		["@diff.delta"] = { link = "Changed" },
	}
end

return M
