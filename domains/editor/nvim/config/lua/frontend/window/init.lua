---@type Plugin
return {
	"window-management",
	virtual = true,
	event = "VeryLazy",
	config = function()
		require("frontend.window.hydra").setup()
	end,
}
