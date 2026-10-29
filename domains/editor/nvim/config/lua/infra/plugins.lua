---@type Plugin[]
return {
	{
		"nvim-lua/plenary.nvim",
	},
	{
		"nvim-tree/nvim-web-devicons",
	},
	{
		"rafamadriz/friendly-snippets",
	},
	{
		"lewis6991/gitsigns.nvim",
		event = "VeryLazy",
		config = function()
			local Keybinder = require("common.Keybinder")

			require("gitsigns").setup({
				on_attach = function(bufnr)
					local gs = require("gitsigns")
					-- Respect the global hunk switch on every attach.
					pcall(require("frontend.tools.git_hunk_display").apply)
					local binder = Keybinder.new(bufnr, "GITSIGNS")

					binder:nmap("]c", function()
						if vim.wo.diff then
							vim.cmd.normal({ "]c", bang = true })
						else
							gs.nav_hunk("next")
						end
					end, { desc = "Next hunk" })

					binder:nmap("[c", function()
						if vim.wo.diff then
							vim.cmd.normal({ "[c", bang = true })
						else
							gs.nav_hunk("prev")
						end
					end, { desc = "Previous hunk" })

					binder:nmap("<leader>gp", function()
						gs.preview_hunk()
					end, { desc = "Preview hunk" })

					binder:nmap("<leader>gb", function()
						gs.blame_line({ full = true })
					end, { desc = "Blame line" })

					binder:nmap("<leader>gt", function()
						gs.diffthis()
					end, { desc = "Diff this file" })

					binder:nmap("<leader>gQ", function()
						vim.cmd("Gitsigns setqflist all")
					end, { desc = "All hunks to quickfix" })
				end,
				signs = {
					add = { text = "┃" },
					change = { text = "┃" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
					untracked = { text = "┆" },
				},
				signs_staged = {
					add = { text = "┃" },
					change = { text = "┃" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
					untracked = { text = "┆" },
				},
				update_debounce = 100,
				-- Bg-only hunks: word diff recolors code text.
				word_diff = false,
				preview_config = {
					border = "single",
					style = "minimal",
				},
			})
		end,
	},
}
