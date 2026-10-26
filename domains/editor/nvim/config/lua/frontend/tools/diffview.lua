---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"sindrets/diffview.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	event = "VeryLazy",
	cmd = {
		"DiffviewOpen",
		"DiffviewClose",
		"DiffviewToggleFiles",
		"DiffviewFocusFiles",
		"DiffviewFileHistory",
		"DiffviewRefresh",
	},
	config = function()
		require("diffview").setup({
			enhanced_diff_hl = true,
			use_icons = true,
			show_help_hints = false,
			view = {
				merge_tool = { layout = "diff3_mixed" },
			},
			file_panel = {
				win_config = { width = 35 },
			},
			file_history_panel = {
				win_config = { width = 35 },
			},
		})

		local binder = Keybinder.new(nil, "DIFFVIEW")

		binder:nmap("<leader>gd", function()
			vim.cmd("DiffviewOpen")
		end, { desc = "Review working tree in tab" })

		binder:nmap("<leader>gm", function()
			vim.ui.input({ prompt = "Diff base: ", default = "origin/main" }, function(base)
				if base ~= nil and base ~= "" then
					vim.cmd("DiffviewOpen " .. base .. "...HEAD")
				end
			end)
		end, { desc = "Review PR range against base" })

		binder:nmap("<leader>gh", function()
			local file = vim.fn.expand("%")
			if file == "" then
				vim.notify("Diffview: no file in current buffer", vim.log.levels.WARN)
				return
			end
			vim.cmd("DiffviewFileHistory " .. vim.fn.fnameescape(file))
		end, { desc = "History of current file" })

		binder:vmap("<leader>gh", function()
			local start_line = vim.fn.line("v")
			local end_line = vim.fn.line(".")
			if start_line > end_line then
				start_line, end_line = end_line, start_line
			end
			vim.cmd("DiffviewFileHistory " .. start_line .. "," .. end_line)
		end, { desc = "History of visual selection" })

		binder:nmap("<leader>gq", function()
			vim.cmd("DiffviewClose")
		end, { desc = "Close diff review" })
	end,
}
