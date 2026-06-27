local M = {}

---@param direction "j"|"k"
M.move_text_vertical = function(direction)
	-- 1. Force exit visual mode to lock in the '< and '> marks
	vim.cmd([[:execute "normal! \<ESC>"]])

	-- 2. Execute the move command based on those locked marks
	if direction == "j" then
		vim.cmd("silent! '<,'>move '>+1")
	elseif direction == "k" then
		vim.cmd("silent! '<,'>move '<-2")
	end

	-- 3. Re-select the moved text and auto-indent it
	vim.cmd("normal! gv=gv")
end

---@param direction "h"|"l"
M.move_text_horizontal = function(direction)
	-- Shift text left or right, then immediately re-select it
	local action = (direction == "h") and "<" or ">"
	vim.cmd(string.format("normal! %sgv", action))
end

return M
