local Keybinder = require("common.Keybinder")

---@class DoktorKeybinderModule
local M = {}

---@param bufnr integer
---@param win_id integer
---@param items DoktorDiagnosticItem[]
function M.setup_navigation_keys(bufnr, win_id, items)
	local binder = Keybinder.new(bufnr, "DOKTOR-NAVIGATOR")

	binder:nmap("<CR>", function()
		local cursor_pos = vim.api.nvim_win_get_cursor(win_id)
		local targeted_row = cursor_pos[1]
		local selected_diagnostic = items[targeted_row]

		if not selected_diagnostic then
			return
		end

		vim.api.nvim_win_close(win_id, true)

		vim.cmd("edit " .. vim.fn.fnameescape(selected_diagnostic.filename))

		vim.api.nvim_win_set_cursor(0, { selected_diagnostic.lnum + 1, selected_diagnostic.col })
	end, "Snap viewport focus to targeted inline diagnostic item")

	local teardown_keys = { "q", "<Esc>" }
	for _, key in ipairs(teardown_keys) do
		binder:nmap(key, function()
			if vim.api.nvim_win_is_valid(win_id) then
				vim.api.nvim_win_close(win_id, true)
			end
		end, "Close and purge active Doktor navigator buffer layer")
	end
end

return M
