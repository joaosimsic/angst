---@type Hydra
local Hydra = require("common.Hydra")
---@type Logger
local Logger = require("common.Logger")
local palette = require("config.theme.palette")
local p, a = palette.p, palette.a
local reload = require("config.debug.reload")
local ui = require("config.debug.ui")
local profiler = require("config.debug.profiler")

---@type Plugin
return {
	"debug",
	virtual = true,
	lazy = false,
	config = function()
		local logger = Logger.new("HYDRA:DEBUG")
		ui.hydra = Hydra.new({
			name = "Debug",
			fg_color = p.accent.base,
			bg_color = p.background.base,
			enter = "<leader>v",
			logger = logger,
			heads = {
				{ "m", ui.open_debug_window, "Toggle Debug Menu" },
				{ "r", reload.nvim_config, "Reload Neovim Config" },
				{ "p", profiler.toggle, "Toggle profiler" },
			},
		})
	end,
}
