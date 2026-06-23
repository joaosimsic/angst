require("config.theme")

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local function configure_clipboard()
	local is_remote = vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil
	local has_display = vim.env.DISPLAY ~= nil or vim.env.WAYLAND_DISPLAY ~= nil

	if not is_remote and has_display then
		return
	end

	local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
	if not ok then
		return
	end

	vim.g.clipboard = {
		name = "OSC 52",
		copy = {
			["+"] = osc52.copy("+"),
			["*"] = osc52.copy("*"),
		},
		paste = {
			["+"] = osc52.paste("+"),
			["*"] = osc52.paste("*"),
		},
	}
end

configure_clipboard()

vim.opt.equalalways = false

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.clipboard = "unnamedplus"

vim.opt.relativenumber = true
vim.opt.number = true

vim.opt.termguicolors = true

vim.opt.cursorline = true

vim.opt.colorcolumn = "100,101"

vim.o.guicursor = "n-v-c:block"

vim.diagnostic.config({
	virtual_text = false,
	virtual_lines = {
		only_current_line = true,
	},
	severity_sort = true,
	float = { border = "none" },
	update_in_insert = false,
})

vim.opt.showmode = false
