return {
	{
		"GustavEikaas/easy-dotnet.nvim",
		ft = { "cs" },
		config = true,
		keys = {
			{ "<leader>dr", "<cmd>Dotnet run<cr>", desc = "Dotnet Run" },
			{ "<leader>dt", "<cmd>Dotnet test<cr>", desc = "Dotnet Test" },
			{ "<leader>ds", "<cmd>Dotnet select<cr>", desc = "Select Dotnet Solution" },
		},
	},
	{
		"seblyng/roslyn.nvim",
		ft = { "cs" },
		config = function()
			require("roslyn").setup({
				args = {
					"--logLevel=Information",
					"--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.get_log_path()),
					"--stdio",
				},
				capabilities = require("backend.engines.completion.config").capabilities(),
			})
		end,
	},
}
