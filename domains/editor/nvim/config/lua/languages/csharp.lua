return {
	{
		"GustavEikaas/easy-dotnet.nvim",
		dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
		config = function()
			require("easy-dotnet").setup()
		end,
		keys = {
			{ "<leader>dr", "<cmd>Dotnet run<cr>", desc = "Dotnet Run" },
			{ "<leader>dt", "<cmd>Dotnet test<cr>", desc = "Dotnet Test" },
			{ "<leader>ds", "<cmd>Dotnet select<cr>", desc = "Select Dotnet Solution" },
		},
	},
	{
		"seblyng/roslyn.nvim",
		ft = "cs",
		config = function()
			require("roslyn").setup({
				args = {
					"--logLevel=Information",
					"--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.get_log_path()),
					"--stdio",
				},
				capabilities = require("cmp_nvim_lsp").default_capabilities(),
			})
		end,
	},
}
