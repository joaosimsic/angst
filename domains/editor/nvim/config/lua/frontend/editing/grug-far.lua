---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"MagicDuck/grug-far.nvim",
	event = "VeryLazy",
	cmd = { "GrugFar" },
	config = function()
		require("grug-far").setup({})

		local binder = Keybinder.new(nil, "GRUG-FAR")

		binder:nmap("<leader>g", function()
			require("grug-far").open({
				prefills = { search = vim.fn.expand("<cword>") },
			})
		end, { desc = "Grug Far word under cursor" })

		binder:vmap("<leader>g", function()
			require("grug-far").with_visual_selection()
		end, { desc = "Grug Far visual selection" })
	end,
}
