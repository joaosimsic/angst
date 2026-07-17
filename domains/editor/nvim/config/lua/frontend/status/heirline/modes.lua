local p = require("config.theme.palette")

---@meta

---@class ModeConfig
---@field fg string
---@field bg string
---@field label string

local M = {}

---@type table<string, ModeConfig>
M.mode_colors = {
	n = { fg = p.background.base, bg = p.foreground.base, label = "NORMAL" },
	o = { fg = p.background.base, bg = p.foreground.base, label = "OP-PENDING" },
	i = { fg = p.background.base, bg = p.foreground.variant, label = "INSERT" },
	v = { fg = p.background.base, bg = p.surface.variant, label = "VISUAL" },
	V = { fg = p.background.base, bg = p.surface.variant, label = "V-LINE" },
	["\22"] = { fg = p.background.base, bg = p.surface.variant, label = "V-BLOCK" },
	s = { fg = p.background.base, bg = p.surface.base, label = "SELECT" },
	S = { fg = p.background.base, bg = p.surface.base, label = "S-LINE" },
	["\19"] = { fg = p.background.base, bg = p.surface.base, label = "S-BLOCK" },
	r = { fg = p.background.base, bg = p.accent.base, label = "REPLACE" },
	R = { fg = p.background.base, bg = p.accent.base, label = "REPLACE" },
	c = { fg = p.background.base, bg = p.accent.base, label = "COMMAND" },
	t = { fg = p.background.base, bg = p.accent.variant, label = "TERMINAL" },
}

---@type ModeConfig
M.mode_fallback = {
	fg = p.accent.base,
	bg = p.background.variant,
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
		if vim.bo[bufnr].buftype ~= "terminal" then
			return "n"
		end
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
