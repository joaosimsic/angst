local M = {}

---@alias Direction "left" | "right" | "up" | "down"

---@param dir Direction
---@return Direction
local function invert_dir(dir)
	if dir == "left" then
		return "right"
	elseif dir == "right" then
		return "left"
	elseif dir == "up" then
		return "down"
	else
		return "up"
	end
end

---@param win integer
---@param dir Direction
---@return boolean
local function have_neighbor_to(win, dir)
	local neighbor = vim.api.nvim_win_call(win, function()
		vim.cmd.wincmd(({
			left = "h",
			right = "l",
			up = "k",
			down = "j",
		})[dir])
		return vim.api.nvim_get_current_win()
	end)
	local n_winnr = vim.api.nvim_win_get_number(neighbor)
	local w_winnr = vim.api.nvim_win_get_number(win)
	return n_winnr ~= w_winnr
end

---@param win integer
---@param amount integer
---@param dir Direction
local function resize_normal(win, amount, dir)
	local postfix = (dir == "left" or dir == "right") and "width" or "height"
	local setter = vim.api["nvim_win_set_" .. postfix]
	local getter = vim.api["nvim_win_get_" .. postfix]

	if dir == "up" or dir == "down" then
		if not have_neighbor_to(win, "down") and not have_neighbor_to(win, "up") then
			return
		end
	end

	if dir == "left" or dir == "up" then
		local diff = have_neighbor_to(win, invert_dir(dir)) and -amount or amount
		setter(win, getter(win) + diff)
	else
		local diff = have_neighbor_to(win, dir) and amount or -amount
		setter(win, getter(win) + diff)
	end
end

---@param win integer
---@param amount integer
---@param dir Direction
local function resize_float(win, amount, dir)
	local postfix = (dir == "left" or dir == "right") and "width" or "height"
	local setter = vim.api["nvim_win_set_" .. postfix]
	local getter = vim.api["nvim_win_get_" .. postfix]

	if dir == "down" or dir == "right" then
		setter(win, getter(win) + amount)
	else
		setter(win, getter(win) - amount)
	end
end

---@param win integer
---@param amount integer
---@param dir Direction
function M.resize(win, amount, dir)
	vim.validate({
		win = { win, "number" },
		amount = {
			amount,
			function(n)
				return n >= 0
			end,
			"positive number",
		},
		key = {
			dir,
			function(s)
				return vim.list_contains({ "left", "right", "up", "down" }, s)
			end,
			"one of left, right, up, and down",
		},
	})

	if vim.api.nvim_win_get_config(win).relative ~= "" then
		resize_float(win, amount, dir)
	else
		resize_normal(win, amount, dir)
	end
end

return M
