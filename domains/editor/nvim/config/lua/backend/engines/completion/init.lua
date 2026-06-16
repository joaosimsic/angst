return {
	{
		"saghen/blink.cmp",
		lazy = false,
		dependencies = { "rafamadriz/friendly-snippets" },
		version = "1.*",
		config = function()
			require("backend.engines.completion.config").setup()
		end,
	},
}
