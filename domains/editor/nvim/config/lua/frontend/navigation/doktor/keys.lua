---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type DoktorCacheState
local State = require("frontend.navigation.doktor.state")

local M = {}

---@param bufnr integer
---@param win_id integer
---@return nil
function M.setup_navigation_keys(bufnr, win_id)
	---@type Keybinder
	local binder = Keybinder.new(bufnr, "DOKTOR-NAVIGATOR")

	binder:nmap("<CR>", function()
		---@type integer[]
		local cursor_pos = vim.api.nvim_win_get_cursor(win_id)
		---@type integer
		local targeted_row = cursor_pos[1]

		---@type DoktorDiagnosticItem?
		local selected_diagnostic = State.row_map[targeted_row]

		if not selected_diagnostic then
			return
		end

		if vim.api.nvim_win_is_valid(win_id) then
			vim.api.nvim_win_close(win_id, true)
		end

		---@type integer
		local target_buf = vim.fn.bufnr(selected_diagnostic.filename, true)
		vim.api.nvim_set_current_buf(target_buf)
		vim.api.nvim_win_set_cursor(0, { selected_diagnostic.lnum + 1, selected_diagnostic.col })
	end, "Snap viewport focus to targeted inline diagnostic item")

	---@type string[]
	local teardown_keys = { "q", "<Esc>", "<C-c>" }
	for _, key in ipairs(teardown_keys) do
		binder:nmap(key, function()
			if vim.api.nvim_win_is_valid(win_id) then
				vim.api.nvim_win_close(win_id, true)
			end
		end, "Close and purge active Doktor navigator buffer layer")
	end
end

return M
