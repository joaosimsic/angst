local Hydra = require("common.Hydra")
local reload = require("config.debug.reload")
local ui = require("config.debug.ui")

---@type Plugin
return {
	"debug",
	virtual = true,
	lazy = false,
	config = function()
		ui.hydra = Hydra.new({
			name = "Debug",
			fg_color = "yellow_bright",
			bg_color = "black",
			enter = "<leader>v",
			heads = {
				{ "m", ui.open_debug_window, "Toggle Debug Menu" },
				{ "r", reload.nvim_config, "Reload Neovim Config" },
			},
		})
	end,
}
