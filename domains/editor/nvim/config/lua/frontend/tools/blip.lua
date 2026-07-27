---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"blip",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local binder = Keybinder.new(nil, "BLIP")
		local blip = require("blip")
		binder:set_debug(true)
		binder:map({ "n", "v" }, "<leader>m", blip.ask, { desc = "Ask about code" })
		binder:nmap("<leader>q", blip.dismiss, { desc = "Dismiss blip response" })
		binder:nmap("<leader>y", blip.comment, { desc = "Insert explanations as comments" })
	end,
}
