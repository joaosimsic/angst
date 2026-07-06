---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"kdheepak/lazygit.nvim",
	event = "VeryLazy",
	cmd = {
		"LazyGit",
		"LazyGitConfig",
		"LazyGitCurrentFile",
		"LazyGitFilter",
		"LazyGitFilterCurrentFile",
	},
	config = function()
		local binder = Keybinder.new(nil, "LAZYGIT")

		binder:nmap("<leader>lg", function()
			vim.cmd("LazyGit")
		end, { desc = "Open lazygit" })
	end,
}
