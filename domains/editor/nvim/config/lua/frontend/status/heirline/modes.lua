local c = require("config.theme").colors

---@meta

---@class ModeConfig
---@field fg string
---@field bg string
---@field label string

local M = {}

---@type table<string, ModeConfig>
M.mode_colors = {
	n = { fg = c.black, bg = c.base, label = "NORMAL" },
	o = { fg = c.black, bg = c.base, label = "OP-PENDING" },
	i = { fg = c.black, bg = c.bright, label = "INSERT" },
	v = { fg = c.black, bg = c.green_bright, label = "VISUAL" },
	V = { fg = c.black, bg = c.green_bright, label = "V-LINE" },
	["\22"] = { fg = c.black, bg = c.green_bright, label = "V-BLOCK" },
	s = { fg = c.black, bg = c.blue_bright, label = "SELECT" },
	S = { fg = c.black, bg = c.blue_bright, label = "S-LINE" },
	["\19"] = { fg = c.black, bg = c.blue_bright, label = "S-BLOCK" },
	r = { fg = c.black, bg = c.yellow_bright, label = "REPLACE" },
	R = { fg = c.black, bg = c.yellow_bright, label = "REPLACE" },
	c = { fg = c.black, bg = c.red_bright, label = "COMMAND" },
	t = { fg = c.black, bg = c.magenta_bright, label = "TERMINAL" },
}

---@type ModeConfig
M.mode_fallback = {
	fg = c.base,
	bg = c.surface,
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
