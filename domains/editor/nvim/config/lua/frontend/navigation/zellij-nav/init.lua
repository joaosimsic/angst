return {
	"zellij-navigation",
  virtual = true,
	event = "VeryLazy",
	cond = function()
		return vim.fn.executable("zellij") == 1 and vim.env.ZELLIJ ~= nil
	end,
	config = function()
		require("frontend.navigation.zellij-nav.keys").setup()
	end,
}
