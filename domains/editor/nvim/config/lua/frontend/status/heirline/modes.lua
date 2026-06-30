local c = require("config.theme.colors").get()

---@meta

---@class ModeConfig
---@field fg string
---@field bg string
---@field label string

local M = {}

---@type table<string, ModeConfig>
M.mode_colors = {
	n = { fg = c.mode.fg, bg = c.mode.normal, label = "NORMAL" },
	o = { fg = c.mode.fg, bg = c.mode.normal, label = "OP-PENDING" },
	i = { fg = c.mode.fg, bg = c.mode.insert, label = "INSERT" },
	v = { fg = c.mode.fg, bg = c.mode.visual, label = "VISUAL" },
	V = { fg = c.mode.fg, bg = c.mode.visual, label = "V-LINE" },
	["\22"] = { fg = c.mode.fg, bg = c.mode.visual, label = "V-BLOCK" },
	s = { fg = c.mode.fg, bg = c.mode.select, label = "SELECT" },
	S = { fg = c.mode.fg, bg = c.mode.select, label = "S-LINE" },
	["\19"] = { fg = c.mode.fg, bg = c.mode.select, label = "S-BLOCK" },
	r = { fg = c.mode.fg, bg = c.mode.replace, label = "REPLACE" },
	R = { fg = c.mode.fg, bg = c.mode.replace, label = "REPLACE" },
	c = { fg = c.mode.fg, bg = c.mode.command, label = "COMMAND" },
	t = { fg = c.mode.fg, bg = c.mode.terminal, label = "TERMINAL" },
}

---@type ModeConfig
M.mode_fallback = {
	fg = c.mode.fallbackFg,
	bg = c.mode.fallbackBg,
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

---@return string
M.effective_mode = function()
	local mode = vim.fn.mode()
	if mode == "t" then
		local bufnr = vim.api.nvim_get_current_buf()
		local ok, status = pcall(vim.fn.term_getstatus, bufnr)
		if ok and status and status:find("finished") then
			return "n"
		end
	end
	return mode
end

---@return ModeConfig
M.get_mode_data = function()
	return M.mode_colors[M.effective_mode()] or M.mode_fallback
end

---@return string
M.mode_hl_name = function()
	return M.hl_name_map[M.effective_mode()] or "HeirlineModeUnknown"
end

return M
