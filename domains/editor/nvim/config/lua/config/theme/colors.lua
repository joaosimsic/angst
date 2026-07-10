local palette = require("config.theme.palette").get()

local raw = palette.palette
local ui = palette.ui
local syntax = palette.syntax
local diagnostic = palette.diagnostic
local ansi = palette.ansi

---@type ThemeColors
local colors = {
	editor = {
		fg = ui.fg,
		bg = ui.bg,
		bright = ui.bright,
		muted = ui.muted,
		dim = raw.dim,
		comment = ui.comment,
		surface = ui.surface,
		subtle = ui.subtle,
		accent = ui.accent,
		border = ui.border,
		selectionBg = ui.selectionBg,
		selectionFg = ui.selectionFg,
		overlay = ui.overlay,
		prompt = ui.prompt,
	},
	syntax = {
		comment = syntax.comment,
		keyword = syntax.keyword,
		string = syntax.string,
		["function"] = syntax["function"],
		variable = syntax.variable,
		constant = syntax.constant,
		operator = syntax.operator,
		property = syntax.property,
		type = syntax.type,
		number = syntax.number,
		punctuation = syntax.punctuation,
		preproc = ansi.blue,
		special = ansi.cyan,
		label = ansi.cyan,
		tag = ansi.yellow,
	},
	diagnostic = {
		error = diagnostic.error,
		warn = diagnostic.warning,
		info = diagnostic.info,
		hint = diagnostic.hint,
		ok = diagnostic.success,
	},
	diff = {
		add = diagnostic.success,
		change = diagnostic.warning,
		delete = diagnostic.error,
		text = diagnostic.warning,
	},
	status = {
		fg = ui.subtle,
		bg = ui.surface,
		active = ui.bright,
		inactive = raw.dim,
		muted = ui.muted,
		surface = ui.surface,
		positionFg = ui.bg,
		positionBg = ansi.magenta,
	},
	mode = {
		fg = ui.bg,
		normal = ui.fg,
		insert = ui.bright,
		visual = ansi.green,
		select = ansi.blue,
		replace = ansi.yellow,
		command = ansi.red,
		terminal = ansi.magenta,
		fallbackFg = ui.subtle,
		fallbackBg = ui.surface,
	},
	git = {
		branch = ui.bright,
		add = diagnostic.success,
		change = diagnostic.warning,
		delete = diagnostic.error,
	},
	rainbow = {
		syntax.keyword,
		syntax.operator,
		ui.bright,
		syntax.variable,
		syntax.type,
	},
	debug = {
		border = ui.surface,
		header = ui.accent,
		info = diagnostic.info,
		label = ui.subtle,
		muted = ui.comment,
		ok = diagnostic.success,
		tabActiveFg = ui.bg,
		tabActiveBg = ui.accent,
		tabInactiveFg = raw.dim,
		tabInactiveBg = ui.surface,
		value = ui.fg,
		warn = diagnostic.warning,
	},
}

local keys = {
	fg = colors.editor.fg,
	bg = colors.editor.bg,
	base = colors.editor.fg,
	black = colors.editor.bg,
	bright = colors.editor.bright,
	dim = colors.editor.dim,
	subtle = colors.editor.subtle,
	accent = colors.editor.accent,
	surface = colors.editor.surface,
	comment = colors.editor.comment,
	red = colors.diagnostic.error,
	red_bright = ansi.red,
	green = colors.diagnostic.ok,
	green_bright = ansi.green,
	yellow = colors.diagnostic.warn,
	yellow_bright = ansi.yellow,
	blue = colors.diagnostic.hint,
	blue_bright = ansi.blue,
	magenta = colors.syntax.constant,
	magenta_bright = ansi.magenta,
	cyan = colors.diagnostic.info,
	cyan_bright = ansi.cyan,
}

local M = {}

---@return ThemeColors
M.get = function()
	return colors
end

---@param key ThemeColorKey|nil
---@return string
M.resolve = function(key)
	return keys[key or "fg"] or colors.editor.fg
end

return M
