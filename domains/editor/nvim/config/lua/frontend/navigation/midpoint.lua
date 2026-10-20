---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"midpoint",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local binder = Keybinder.new(nil, "MIDPOINT")

		binder:nmap("M", "50%", { desc = "Go to middle of file" })
	end,
}
