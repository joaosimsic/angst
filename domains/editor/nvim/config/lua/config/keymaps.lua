vim.g.mapleader = " "

local map = vim.keymap.set

-- Editor: Line movement and manipulation
map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

map("n", "J", "mzJ`z")

map("x", "<leader>p", '"_dP', { noremap = true, silent = true })

map({ "n", "v" }, "<leader>y", [["+y]])
map("n", "<leader>Y", [["+Y]])

map({ "n", "v" }, "<leader>d", [["_d]])

-- Editor: Search and replace
vim.keymap.set({ "n", "x" }, "<leader>s", function()
	local mode = vim.fn.mode()
	local search_text = ""

	if mode == "v" or mode == "V" or mode == "\22" then
		vim.cmd('normal! "vy')
		search_text = vim.fn.getreg("v")
		search_text = vim.fn.escape(search_text, "\\/.*$^~[]")
	else
		search_text = vim.fn.expand("<cword>")
	end

	local cmd = string.format(":%s/\\<%s\\>/%s/gc", "%s", search_text, search_text)

	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(cmd, true, false, true), "c", true)
end, { desc = "Pre-fill substitution for selection or word, whole file" })

-- Navigation: Centering cursor improvements
map("n", "<C-d>", "<C-d>zz", { noremap = true, silent = true })
map("n", "<C-u>", "<C-u>zz", { noremap = true, silent = true })

map({ "n", "v" }, "k", "kzz")
map({ "n", "v" }, "j", "jzz")

-- Navigation: Search centering
map("n", "n", "nzzzv", { noremap = true, silent = true })
map("n", "N", "Nzzzv", { noremap = true, silent = true })

-- Navigation: Quickfix list with centering
map("n", "<C-k>", "<cmd>cnext<CR>zz")
map("n", "<C-j>", "<cmd>cprev<CR>zz")

-- Navigation: Location list with centering
map("n", "<leader>k", "<cmd>lnext<CR>zz")
map("n", "<leader>j", "<cmd>lprev<CR>zz")

-- Navigation: Disable arrow keys
vim.api.nvim_set_keymap("n", "<Up>", "<Nop>", { noremap = true })
vim.api.nvim_set_keymap("n", "<Down>", "<Nop>", { noremap = true })
vim.api.nvim_set_keymap("n", "<Left>", "<Nop>", { noremap = true })
vim.api.nvim_set_keymap("n", "<Right>", "<Nop>", { noremap = true })

-- Diagnostics: Toggle diagnostic float
map("n", "<leader>e", function()
	local float_toggle = require("utils.float_toggle")
	float_toggle.toggle("diagnostic", function()
		return vim.diagnostic.open_float(nil, { focusable = false })
	end)
end, { desc = "Toggle diagnostic float" })

-- Files: Open Netrw
map("n", "<leader>pv", vim.cmd.Ex)

-- Tmux: Create new window tmux-sessionizer
map("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer.sh<CR>")

-- Tmux: Open cht.sh
map("n", "<C-q>", "<cmd>silent !tmux neww tmux-cht.sh<CR>")

-- Tmux: Open NVim config
map("n", "<leader>vpp", "<cmd>silent !tmux neww nvim ~/.config/nvim/init.lua<CR>")
