-- WHAT A MESS

local Keybinder = require("common.Keybinder")

local M = {}

function M.setup()
	local fzf = require("fzf-lua")
	local binder = Keybinder.new(nil, "FZF")

	binder:nmap("<leader>ff", fzf.files, { desc = "Find files" })
	binder:nmap("<leader>fg", fzf.live_grep, { desc = "Live grep" })
	binder:nmap("<leader>fb", fzf.buffers, { desc = "Buffers" })
	binder:nmap("<leader>fo", fzf.oldfiles, { desc = "Recent files" })
	binder:nmap("<leader>fh", fzf.help_tags, { desc = "Help tags" })
end

function M.on_picker_create()
	local current_buf = vim.api.nvim_get_current_buf()
	---@type Keybinder
	local binder = Keybinder.new(current_buf, "FZF-MODAL")

	local function send_macro(keys)
		local clean_keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
		vim.api.nvim_feedkeys(clean_keys, "t", false)
	end

	binder:map({ "t" }, "<C-c>", function()
		send_macro([[<C-\><C-n>]])
	end, { desc = "Exit terminal mode" })

	local motions = {
		["j"] = "i<C-j><C-\\><C-n>",
		["k"] = "i<C-k><C-\\><C-n>",
		["<C-d>"] = "i<C-d><C-\\><C-n>",
		["<C-u>"] = "i<C-u><C-\\><C-n>",
		["<CR>"] = "i<CR><C-\\><C-n>",
		["<Tab>"] = "i<Tab><C-\\><C-n>",
		["q"] = "i<Esc>",
		["v"] = "i<C-v><C-\\><C-n>",
		["h"] = "i<C-z><C-\\><C-n>",
	}

	for key, macro in pairs(motions) do
		binder:nmap(key, function()
			send_macro(macro)
		end, { desc = "Motion " .. key })
	end

	binder:nmap("i", function()
		vim.cmd("startinsert")
	end, { desc = "Insert mode" })

	binder:nmap("a", function()
		vim.cmd("startinsert")
	end, { desc = "Append mode" })
end

return M
