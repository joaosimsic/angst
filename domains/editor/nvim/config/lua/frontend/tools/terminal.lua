---@type Keybinder
local Keybinder = require("common.Keybinder")

local M = {}

local term_buf = nil
local term_win = nil

local function close()
	if term_win and vim.api.nvim_win_is_valid(term_win) then
		vim.api.nvim_win_close(term_win, true)
	end
	term_win = nil
end

local function open()
	if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
		vim.cmd("botright vsplit")
		vim.api.nvim_win_set_buf(0, term_buf)
		term_win = vim.api.nvim_get_current_win()
	else
		vim.cmd("botright vsplit | terminal")
		term_buf = vim.api.nvim_get_current_buf()
		term_win = vim.api.nvim_get_current_win()
	end

	vim.cmd("startinsert!")

	local binder = Keybinder.new(term_buf, "TERMINAL")
	binder:nmap("q", close, { desc = "Close terminal" })
	binder:nmap("<Esc>", close, { desc = "Close terminal" })
end

local function toggle()
	if term_win and vim.api.nvim_win_is_valid(term_win) then
		close()
		return
	end
	open()
end

vim.api.nvim_create_autocmd("WinClosed", {
	pattern = "*",
	callback = function(args)
		if term_win and args.match == tostring(term_win) then
			term_win = nil
		end
	end,
})

---@type Plugin
return {
	"terminal",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local binder = Keybinder.new(nil, "TERMINAL")
		binder:nmap("<leader>z", toggle, { desc = "Toggle terminal" })
	end,
}
