---@type Plugin
return {
	"nav-files",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local Keybinder = require("common.Keybinder")

		local binder = Keybinder.new(nil, "FILES")

		binder:nmap("<leader>fl", function()
			vim.cmd("buffer #")
		end, "Last visited file")
	end,
}
