---@type Plugin
return {
	"env",
	virtual = true,
	lazy = false,
	priority = 1001,
	config = function()
		vim.opt.equalalways = false
		vim.opt.tabstop = 4
		vim.opt.softtabstop = 4
		vim.opt.shiftwidth = 4
		vim.opt.expandtab = true
		vim.opt.relativenumber = true
		vim.opt.number = true
		vim.opt.termguicolors = true
		vim.opt.cursorline = true
		vim.opt.colorcolumn = "100,101"
		vim.o.guicursor = "n-v-c:block"
		vim.opt.showmode = false
		vim.opt.scrolloff = 999
		vim.opt.timeoutlen = 300
		vim.opt.ttimeoutlen = 10
    vim.opt.splitright = true
    vim.opt.splitbelow = true
    vim.opt.signcolumn = "yes"
	end,
}
