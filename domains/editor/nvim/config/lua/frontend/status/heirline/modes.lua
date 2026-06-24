local p = require("config.theme.palette").get()

---@meta

---@class ModeConfig
---@field fg string
---@field bg string
---@field label string

local M = {}

---@type table<string, ModeConfig>
M.mode_colors = {
	n = { fg = p.black, bg = p.base, label = "NORMAL" },
	o = { fg = p.black, bg = p.base, label = "OP-PENDING" },
	i = { fg = p.black, bg = p.bright, label = "INSERT" },
	v = { fg = p.black, bg = p.green_bright, label = "VISUAL" },
	V = { fg = p.black, bg = p.green_bright, label = "V-LINE" },
	["\22"] = { fg = p.black, bg = p.green_bright, label = "V-BLOCK" },
	s = { fg = p.black, bg = p.blue_bright, label = "SELECT" },
	S = { fg = p.black, bg = p.blue_bright, label = "S-LINE" },
	["\19"] = { fg = p.black, bg = p.blue_bright, label = "S-BLOCK" },
	r = { fg = p.black, bg = p.yellow_bright, label = "REPLACE" },
	R = { fg = p.black, bg = p.yellow_bright, label = "REPLACE" },
	c = { fg = p.black, bg = p.red_bright, label = "COMMAND" },
	t = { fg = p.black, bg = p.magenta_bright, label = "TERMINAL" },
}

---@type ModeConfig
M.mode_fallback = {
	fg = p.base,
	bg = p.surface,
	label = "UNKNOWN",
}

---@type table<string, string>
M.hl_name_map = {
	n = "HeirlineModeNormal",
	o = "HeirlineModeNormal",
	i = "HeirlineModeInsert",
	v = "HeirlineModeVisual",
	V = "HeirlineModeVisual",
	["\22"] = "HeirlineModeVisual",
	s = "HeirlineModeVisual",
	S = "HeirlineModeVisual",
	["\19"] = "HeirlineModeVisual",
	r = "HeirlineModeReplace",
	R = "HeirlineModeReplace",
	c = "HeirlineModeCommand",
	t = "HeirlineModeTerminal",
}

---@return ModeConfig
M.get_mode_data = function()
	return M.mode_colors[vim.fn.mode()] or M.mode_fallback
end

---@return string
M.mode_hl_name = function()
	return M.hl_name_map[vim.fn.mode()] or "HeirlineModeUnknown"
end

return M
