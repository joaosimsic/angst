return {
	dir = vim.fn.stdpath("config"),
	name = "zellij-navigation",
	event = "VeryLazy",
	cond = function()
		return vim.fn.executable("zellij") == 1 and vim.env.ZELLIJ ~= nil
	end,
	config = function()
		require("frontend.navigation.zellij-nav.keys").setup()
	end,
}
