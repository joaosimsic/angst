local Keybinder = require("common.Keybinder")

local M = {}

function M.bind_float_keys(buf, win, targets)
	---@type Keybinder
	local binder = Keybinder.new(buf, "DOKTOR_WIN")

	binder:nmap("<CR>", function()
		local cursor_row = vim.api.nvim_win_get_cursor(win)[1]
		local target = targets[cursor_row]

		if target then
			vim.api.nvim_win_close(win, true)
			vim.api.nvim_set_current_buf(target.bufnr)
			vim.api.nvim_win_set_cursor(0, { target.lnum + 1, target.col })
		end
	end, "Jump to workspace diagnostic location")

	local function close_float()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	binder:nmap("q", close_float, "Close panel")
	binder:nmap("<Esc>", close_float, "Close panel")
end

return M
