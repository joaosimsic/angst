---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"mikavilpas/yazi.nvim",
	version = "*",
	event = "VeryLazy",
	opts = {
		open_for_directories = false,
		keymaps = {
			show_help = "<f1>",
		},
	},
	init = function()
		vim.g.loaded_netrwPlugin = 1
	end,
	config = function()
		local binder = Keybinder.new(nil, "YAZI")

		binder:nmap("<C-a>", function()
			require("yazi").toggle()
		end, { desc = "Toggle yazi" })
	end,
}
