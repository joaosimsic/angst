local M = {}

local tracked_windows = {}

function M.toggle(key, open_fn)
	local tracked = tracked_windows[key]

	if tracked and tracked.float_win and vim.api.nvim_win_is_valid(tracked.float_win) then
		local current_win = vim.api.nvim_get_current_win()
		if current_win == tracked.float_win or current_win == tracked.source_win then
			vim.api.nvim_win_close(tracked.float_win, true)
			tracked_windows[key] = nil
			if tracked.source_win and vim.api.nvim_win_is_valid(tracked.source_win) then
				vim.api.nvim_set_current_win(tracked.source_win)
			end
			return
		end
	end

	local source_win = vim.api.nvim_get_current_win()

	local result = { open_fn() }

	local new_win = result[2] or M.find_last_float()

	if new_win then
		tracked_windows[key] = {
			float_win = new_win,
			source_win = source_win,
		}
	end
end

function M.find_last_float()
	local wins = vim.api.nvim_list_wins()
	for i = #wins, 1, -1 do
		local config = vim.api.nvim_win_get_config(wins[i])
		if config.relative ~= "" then
			return wins[i]
		end
	end
	return nil
end

function M.close_all()
	for key, tracked in pairs(tracked_windows) do
		if tracked and tracked.float_win and vim.api.nvim_win_is_valid(tracked.float_win) then
			vim.api.nvim_win_close(tracked.float_win, true)
		end
		tracked_windows[key] = nil
	end
end

function M.is_in_float(key)
	local tracked = tracked_windows[key]
	if not tracked or not tracked.float_win then
		return false
	end

	if not vim.api.nvim_win_is_valid(tracked.float_win) then
		return false
	end

	local current_win = vim.api.nvim_get_current_win()
	return current_win == tracked.float_win
end

return M
