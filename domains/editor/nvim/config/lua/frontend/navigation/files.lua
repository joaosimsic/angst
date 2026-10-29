---@type Plugin
return {
	"nav-files",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local Keybinder = require("common.Keybinder")

		local binder = Keybinder.new(nil, "FILES")

		binder:nmap("<leader>fl", function()
			local mark_info = vim.api.nvim_get_mark("0", {})
			local line_num = mark_info[1]
			local file_path = mark_info[4]

			if line_num <= 0 or file_path == "" then
				vim.notify("No previous file found", vim.log.levels.INFO)
				return
			end

			file_path = vim.fn.fnamemodify(file_path, ":p")

			pcall(function()
				vim.cmd("edit " .. vim.fn.fnameescape(file_path))
			end)

			local current_buf_name = vim.api.nvim_buf_get_name(0)
			if vim.fn.fnamemodify(current_buf_name, ":p") == file_path then
				pcall(function()
					vim.api.nvim_win_set_cursor(0, { line_num, mark_info[2] })
				end)
			end
		end, { desc = "Last visited file" })
	end,
}
