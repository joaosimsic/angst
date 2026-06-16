vim.opt.runtimepath:prepend(vim.fn.stdpath("config") .. "/parser")

vim.g.mapleader = " "
vim.g.maplocalleader = " "

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
	virtual_text = true,
	severity_sort = true,
	float = { border = "none" },
	update_in_insert = false,
})
