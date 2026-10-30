---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"NeogitOrg/neogit",
	dependencies = {
		"nvim-lua/plenary.nvim",
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
				diffview = false,
				telescope = false,
			},
		})

		local binder = Keybinder.new(nil, "NEOGIT")

		binder:nmap("<leader>lg", function()
			vim.cmd("Neogit")
		end, { desc = "Neogit status in tab" })

		binder:nmap("<leader>gc", function()
			vim.cmd("Neogit commit")
		end, { desc = "Git commit" })

		binder:nmap("<leader>gm", function()
			vim.cmd("Neogit log")
		end, { desc = "Git log" })
	end,
}
