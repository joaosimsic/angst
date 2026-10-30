---@type Plugin
return {
	"tab-management",
	virtual = true,
	event = "VeryLazy",
	config = function()
		require("frontend.tab.hydra").setup()
	end,
}
