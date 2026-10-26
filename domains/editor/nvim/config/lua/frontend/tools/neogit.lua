---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"NeogitOrg/neogit",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"sindrets/diffview.nvim",
	},
	event = "VeryLazy",
	cmd = {
		"Neogit",
		"NeogitCommit",
		"NeogitLogCurrent",
		"NeogitStash",
		"NeogitResetState",
	},
	config = function()
		require("neogit").setup({
			kind = "tab",
			graph_style = "unicode",
			remember_settings = false,
			disable_commit_confirmation = false,
			status = {
				recent_commit_count = 10,
			},
			integrations = {
				diffview = true,
				telescope = false,
			},
		})

		local binder = Keybinder.new(nil, "NEOGIT")

		binder:nmap("<leader>gs", function()
			vim.cmd("Neogit")
		end, { desc = "Git status in tab" })

		binder:nmap("<leader>gc", function()
			vim.cmd("Neogit commit")
		end, { desc = "Git commit" })

		binder:nmap("<leader>gl", function()
			vim.cmd("Neogit log")
		end, { desc = "Git log" })
	end,
}
