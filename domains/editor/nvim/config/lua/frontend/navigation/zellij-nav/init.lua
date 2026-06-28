---@type Plugin
return {
	"zellij-navigation",
	virtual = true,
	lazy = false,
	cond = function()
		return vim.fn.executable("zellij") == 1
	end,
	config = function()
		require("frontend.navigation.zellij-nav.keys").setup()
	end,
}
