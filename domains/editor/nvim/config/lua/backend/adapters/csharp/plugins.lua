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
}
