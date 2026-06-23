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

	local motions = {
		["j"] = "i<C-j><C-\\><C-n>",
		["k"] = "i<C-k><C-\\><C-n>",
		["<C-d>"] = "i<C-d><C-\\><C-n>",
		["<C-u>"] = "i<C-u><C-\\><C-n>",
	}

	for key, macro in pairs(motions) do
		binder:map("n", key, function()
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(macro, true, true, true), "m", false)
		end, "Motion " .. key)
	end

	binder:map("n", "i", function()
		vim.cmd("startinsert")
	end, "Insert mode")

	binder:map("n", "a", function()
		vim.cmd("startinsert")
	end, "Append mode")
end

return M
