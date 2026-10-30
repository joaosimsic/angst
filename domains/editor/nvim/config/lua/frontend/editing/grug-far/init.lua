local Keybinder = require("common.Keybinder")
local backup = require("frontend.editing.grug-far.backup")
local restore = require("frontend.editing.grug-far.restore")

---@type Plugin
return {
	"MagicDuck/grug-far.nvim",
	event = "VeryLazy",
	cmd = { "GrugFar" },
	config = function()
		require("grug-far").setup({})

		local binder = Keybinder.new(nil, "GRUG-FAR")

		binder:nmap("<leader>r", function()
			local run_id = os.date("%Y%m%d_%H%M%S") .. "_" .. vim.fn.getpid()
			local opts = backup.with_backup({
				prefills = { search = vim.fn.expand("<cword>") },
			}, run_id)
			local inst = require("grug-far").open(opts)
			restore.add_instance_keymaps(inst, run_id)
		end, { desc = "Grug Far word under cursor" })

		binder:vmap("<leader>r", function()
			local run_id = os.date("%Y%m%d_%H%M%S") .. "_" .. vim.fn.getpid()
			local opts = backup.with_backup({}, run_id)
			local inst = require("grug-far").with_visual_selection(opts)
			restore.add_instance_keymaps(inst, run_id)
		end, { desc = "Grug Far visual selection" })

		binder:nmap("<leader>ru", function()
			restore.open_restore()
		end, { desc = "Grug Far Restore" })
	end,
}
