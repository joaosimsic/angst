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
						local preview_inline = gs.preview_hunk_inline or gs.preview_hunk
						preview_inline()
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
				word_diff = false,
			})
		end,
	},
}
