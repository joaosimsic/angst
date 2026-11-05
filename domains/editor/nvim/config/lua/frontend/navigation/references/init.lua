---@type Plugin
return {
	"references",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local Keybinder = require("common.Keybinder")
		local Logger = require("common.Logger")
		local logger = Logger.new("REFERENCES")
		local actions = require("frontend.navigation.references.actions")
		local binder = Keybinder.new(nil, "REFERENCES")

		binder:nmap("gr", function()
			actions.open_word(logger)
		end, { desc = "References for word under cursor" })

		binder:vmap("gr", function()
			actions.open_selection(logger)
		end, { desc = "References for selection" })
	end,
}
