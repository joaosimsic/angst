local palette = require("config.theme.palette").get()
local p = palette.palette
local a = palette.ansi

local M = {}

---@return HighlightGroups
M.get = function()
	return {
		["@comment"] = { link = "Comment" },
		["@comment.documentation"] = { fg = p.dim },
		["@comment.error"] = { fg = a.error, bg = p.background.variant },
		["@comment.note"] = { fg = a.info, bg = p.background.variant },
		["@comment.todo"] = { link = "Todo" },
		["@comment.warning"] = { fg = a.warn, bg = p.background.variant },

		["@constant"] = { link = "Constant" },
		["@constant.builtin"] = { fg = p.accent.variant },
		["@constant.macro"] = { fg = p.accent.variant },
		["@constructor"] = { fg = p.surface.base },
		["@module"] = { fg = p.surface.base },
		["@label"] = { link = "Label" },

		["@string"] = { link = "String" },
		["@string.documentation"] = { fg = p.foreground.variant },
		["@string.escape"] = { fg = p.accent.variant },
		["@string.regexp"] = { fg = p.foreground.base },
		["@string.special"] = { fg = p.accent.variant },
		["@character"] = { link = "Character" },
		["@character.special"] = { fg = p.accent.variant },
		["@number"] = { link = "Number" },
		["@boolean"] = { link = "Boolean" },
		["@number.float"] = { link = "Float" },

		["@function"] = { link = "Function" },
		["@function.builtin"] = { fg = p.foreground.base },
		["@function.call"] = { fg = p.foreground.base },
		["@function.macro"] = { link = "Function" },
		["@function.method"] = { fg = p.foreground.base },
		["@function.method.call"] = { fg = p.foreground.base },

		["@variable"] = { fg = p.foreground.base },
		["@variable.builtin"] = { fg = a.error },
		["@variable.parameter"] = { fg = p.foreground.base, italic = true },
		["@variable.member"] = { fg = p.foreground.base },
		["@property"] = { fg = p.surface.base },
		["@field"] = { fg = p.foreground.base },

		["@type"] = { link = "Type" },
		["@type.builtin"] = { fg = p.surface.base },
		["@type.definition"] = { link = "Typedef" },
		["@type.qualifier"] = { fg = p.accent.base, bold = true },
		["@attribute"] = { fg = p.surface.base },

		["@keyword"] = { link = "Keyword" },
		["@keyword.conditional"] = { link = "Conditional" },
		["@keyword.coroutine"] = { link = "Keyword" },
		["@keyword.debug"] = { fg = a.error },
		["@keyword.directive"] = { fg = p.surface.base },
		["@keyword.directive.define"] = { fg = p.surface.base },
		["@keyword.exception"] = { link = "Exception" },
		["@keyword.function"] = { link = "Keyword" },
		["@keyword.import"] = { link = "Include" },
		["@keyword.operator"] = { fg = p.accent.base },
		["@keyword.repeat"] = { link = "Repeat" },
		["@keyword.return"] = { link = "Keyword" },
		["@keyword.storage"] = { link = "Keyword" },

		["@operator"] = { link = "Operator" },
		["@punctuation.bracket"] = { fg = p.accent.base },
		["@punctuation.delimiter"] = { fg = p.accent.base },
		["@punctuation.special"] = { fg = p.foreground.base },

		["@markup.heading"] = { fg = p.foreground.variant, bold = true },
		["@markup.strong"] = { bold = true },
		["@markup.italic"] = { italic = true },
		["@markup.underline"] = { underline = true },
		["@markup.strikethrough"] = { strikethrough = true },
		["@markup.quote"] = { fg = p.dim, italic = true },
		["@markup.math"] = { fg = p.foreground.base },
		["@markup.raw"] = { fg = p.foreground.variant },
		["@markup.raw.block"] = { fg = p.foreground.variant },
		["@markup.link"] = { fg = p.surface.base, underline = true },
		["@markup.link.label"] = { fg = a.info },
		["@markup.link.url"] = { fg = p.surface.base, underline = true },
		["@markup.list"] = { fg = p.foreground.variant },
		["@markup.list.checked"] = { fg = a.success },
		["@markup.list.unchecked"] = { fg = p.dim },

		["@tag"] = { fg = p.accent.base },
		["@tag.attribute"] = { fg = p.foreground.base, italic = true },
		["@tag.delimiter"] = { fg = p.dim },

		["@diff.plus"] = { fg = a.success },
		["@diff.minus"] = { fg = a.error },
		["@diff.delta"] = { fg = a.warn },
	}
end

return M
