---@type Plugin
return {
	"spring",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local Keybinder = require("common.Keybinder")
		local Logger = require("common.Logger")
		local logger = Logger.new("SPRING")
		local actions = require("frontend.navigation.spring.actions")

		actions.setup(logger)

		local binder = Keybinder.new(nil, "SPRING")
		binder:nmap("gs", actions.toggle, { desc = "Spring pull or release" })
	end,
}
