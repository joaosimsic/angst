---@type Plugin
return {
	"doktor",
	virtual = true,
  lazy = false,
	config = function()
		local Keybinder = require("common.Keybinder")
		local config = require("frontend.navigation.doktor.config")
		local keys = require("frontend.navigation.doktor.keys")

		local global_binder = Keybinder.new(nil, "DOKTOR")
		global_binder:nmap("<leader>xx", function()
			config.open_panel(keys.bind_float_keys)
		end, "Open Doktor diagnostics overview")
	end,
}
