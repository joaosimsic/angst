---@class ZellijNav
local M = {}

---@alias ZellijDirection "Left" | "Down" | "Up" | "Right"

---@param direction NvimDirection
---@param zellij_dir ZellijDirection
local function navigate(direction, zellij_dir)
	local current_win = vim.api.nvim_get_current_win()

	vim.cmd("wincmd " .. direction)

	if current_win == vim.api.nvim_get_current_win() then
		vim.system({ "zellij", "action", "move-focus", zellij_dir })
	end
end

function M.left()
	navigate("h", "Left")
end

function M.down()
	navigate("j", "Down")
end

function M.up()
	navigate("k", "Up")
end

function M.right()
	navigate("l", "Right")
end

return M
