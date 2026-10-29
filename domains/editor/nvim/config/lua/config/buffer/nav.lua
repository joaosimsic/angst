---@type Plugin
return {
	"buffer-nav",
	virtual = true,
	lazy = false,
	config = function()
		local Keybinder = require("common.Keybinder")
		local binder = Keybinder.new(nil, "BUFFER-NAV")

		binder:map({ "n", "x" }, "<C-d>", "<C-d>zz", { desc = "Scroll half-page down" })
		binder:map({ "n", "x" }, "<C-u>", "<C-u>zz", { desc = "Scroll half-page up" })
	end,
}
