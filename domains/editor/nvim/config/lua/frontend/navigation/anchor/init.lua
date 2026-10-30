---@type Plugin
return {
	"anchor",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local Logger = require("common.Logger")
		local logger = Logger.new("ANCHOR")

		require("frontend.navigation.anchor.actions").setup(logger)
		require("frontend.navigation.anchor.commands").setup(logger)
	end,
}
