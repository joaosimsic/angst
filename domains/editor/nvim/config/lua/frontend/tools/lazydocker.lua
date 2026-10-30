---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"crnvl96/lazydocker.nvim",
	event = "VeryLazy",
	config = function()
		local binder = Keybinder.new(nil, "LAZYDOCKER")
		local lazydocker = require("lazydocker")

		lazydocker.setup({
			window = {
				settings = {
					width = 0.900,
					height = 0.900,
					border = "rounded",
					relative = "editor",
				},
			},
		})

		binder:nmap("<leader>ld", function()
			lazydocker.open()
		end, { desc = "Open lazydocker" })
	end,
}
