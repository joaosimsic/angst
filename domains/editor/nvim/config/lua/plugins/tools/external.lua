return {
	{
		"kdheepak/lazygit.nvim",
		lazy = true,
		cmd = {
			"LazyGit",
			"LazyGitConfig",
			"LazyGitCurrentFile",
			"LazyGitFilter",
			"LazyGitFilterCurrentFile",
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		keys = {
			{
				"<leader>lg",
				"<cmd>:LazyGit<CR>",
				mode = "n",
				desc = "Open Lazygit",
			},
		},
	},
	{
		"crnvl96/lazydocker.nvim",
		lazy = true,
		keys = {
			{
				"<leader>ld",
				function()
					require("lazydocker").open()
				end,
				mode = "n",
				desc = "Open Lazydocker",
			},
		},
		config = function()
			require("lazydocker").setup({
				window = {
					settings = {
						width = 0.900,
						height = 0.900,
						border = "rounded",
						relative = "editor",
					},
				},
			})
		end,
	},
	{
		"ramilito/kubectl.nvim",
		keys = {
			{
				"<leader>lk",
				function()
					require("kubectl").toggle({ true })
				end,
				mode = "n",
				desc = "Open kubectl",
			},
		},
		dependencies = "saghen/blink.download",
		config = function()
			---@diagnostic disable-next-line: missing-fields
			require("kubectl").setup({})
		end,
	},
}
