return {
	"echasnovski/mini.nvim",
	event = "VeryLazy",
	config = function()
		require("mini.cmdline").setup()
	end,
}
