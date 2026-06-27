---@type Plugin
return {
	"nav-files",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local Keybinder = require("common.Keybinder")

		local binder = Keybinder.new(nil, "FILES")

		binder:nmap("<leader>fl", function()
			local mark_pos = vim.api.nvim_get_mark("0", {})
			local line_num = mark_pos[1]

			if line_num <= 0 then
				vim.notify("No previous buffer found", vim.log.levels.INFO)
				return
			end

			vim.cmd("normal! '0")
		end, { desc = "Last visited file" })
	end,
}
