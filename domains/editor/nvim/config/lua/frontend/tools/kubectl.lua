---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"ramilito/kubectl.nvim",
	enabled = false,
	event = "VeryLazy",
	dependencies = "saghen/blink.download",
	config = function()
		local binder = Keybinder.new(nil, "KUBECTL")
		local kubectl = require("kubectl")

		---@diagnostic disable-next-line: missing-fields
		kubectl.setup({})

		binder:nmap("<leader>lk", function()
			kubectl.toggle({ true })
		end, { desc = "Open kubectl" })
	end,
}
