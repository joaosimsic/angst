return {
	{
		"mrcjkb/rustaceanvim",
		version = "^5",
		ft = { "rust" },
		config = function()
			vim.g.rustaceanvim = {
				server = {
					default_settings = {
						["rust-analyzer"] = {
							check = { command = "clippy" },
						},
					},
				},
			}
		end,
	},
}
