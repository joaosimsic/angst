local Keybinder = require("common.Keybinder")

local M = {}

function M.setup()
	local fzf = require("fzf-lua")
	local binder = Keybinder.new(nil, "FZF")

	binder:nmap("<leader>ff", fzf.files, "Find files")
	binder:nmap("<leader>fg", fzf.live_grep, "Live grep")
	binder:nmap("<leader>fb", fzf.buffers, "Buffers")
	binder:nmap("<leader>fo", fzf.oldfiles, "Recent files")
	binder:nmap("<leader>fh", fzf.help_tags, "Help tags")
end

function M.on_picker_create()
	local current_buf = vim.api.nvim_get_current_buf()
	local binder = Keybinder.new(current_buf, "FZF-MODAL")

	binder:map("t", "<Esc>", function()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true), "n", false)
	end, "Exit terminal mode")

	binder:map("n", "j", function()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<C-j><C-\\><C-n>", true, true, true), "m", false)
	end, "Move down")

	binder:map("n", "k", function()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<C-k><C-\\><C-n>", true, true, true), "m", false)
	end, "Move up")

	binder:map("n", "i", function()
		vim.cmd("startinsert")
	end, "Enter insert mode")

	binder:map("n", "a", function()
		vim.cmd("startinsert")
	end, "Append focus")
end

return M
