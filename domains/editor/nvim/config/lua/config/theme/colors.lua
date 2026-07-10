local palette = require("config.theme.palette").get()

local p = palette.palette
local a = palette.ansi

---@type ThemeColors
local colors = {
	editor = {
		fg = p.foreground.base,
		bg = p.background.base,
		bright = p.foreground.variant,
		muted = p.dim,
		dim = p.dim,
		comment = p.dim,
		surface = p.background.variant,
		subtle = p.accent.base,
		accent = p.accent.base,
		border = p.foreground.base,
		selectionBg = p.accent.base,
		selectionFg = p.background.variant,
		overlay = p.dim,
		prompt = p.foreground.variant,
	},
	syntax = {
		comment = p.dim,
		keyword = p.accent.base,
		string = p.foreground.variant,
		["function"] = p.foreground.base,
		variable = p.foreground.base,
		constant = p.accent.variant,
		operator = p.accent.base,
		property = p.surface.base,
		type = p.surface.base,
		number = p.accent.base,
		punctuation = p.accent.base,
		preproc = p.surface.base,
		special = p.foreground.base,
		label = p.foreground.base,
		tag = p.accent.base,
	},
	diagnostic = {
		error = a.error,
		warn = a.warn,
		info = a.info,
		hint = p.surface.base,
		ok = a.success,
	},
	diff = {
		add = a.success,
		change = a.warn,
		delete = a.error,
		text = a.warn,
	},
	status = {
		fg = p.accent.base,
		bg = p.background.variant,
		active = p.foreground.variant,
		inactive = p.dim,
		muted = p.dim,
		surface = p.background.variant,
		positionFg = p.background.base,
		positionBg = p.accent.variant,
	},
	mode = {
		fg = p.background.base,
		normal = p.foreground.base,
		insert = p.foreground.variant,
		visual = p.surface.variant,
		select = p.surface.base,
		replace = p.accent.base,
		command = p.dim,
		terminal = p.accent.variant,
		fallbackFg = p.accent.base,
		fallbackBg = p.background.variant,
	},
	git = {
		branch = p.foreground.variant,
		add = a.success,
		change = a.warn,
		delete = a.error,
	},
	rainbow = {
		p.accent.base,
		p.accent.base,
		p.foreground.variant,
		p.foreground.base,
		p.surface.base,
	},
	debug = {
		border = p.background.variant,
		header = p.accent.base,
		info = a.info,
		label = p.accent.base,
		muted = p.dim,
		ok = a.success,
		tabActiveFg = p.background.base,
		tabActiveBg = p.accent.base,
		tabInactiveFg = p.dim,
		tabInactiveBg = p.background.variant,
		value = p.foreground.base,
		warn = a.warn,
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
	red_bright = p.dim,
	green = colors.diagnostic.ok,
	green_bright = p.surface.variant,
	yellow = colors.diagnostic.warn,
	yellow_bright = p.accent.base,
	blue = colors.diagnostic.hint,
	blue_bright = p.surface.base,
	magenta = colors.syntax.constant,
	magenta_bright = p.accent.variant,
	cyan = colors.diagnostic.info,
	cyan_bright = p.foreground.base,
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
