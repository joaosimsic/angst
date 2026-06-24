local M = {}

---@param direction "j"|"k"
M.move_text_vertical = function(direction)
	local start_line = vim.fn.line("v")
	local end_line = vim.fn.line(".")

	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local total_lines = vim.api.nvim_buf_line_count(0)

	if (direction == "k" and start_line <= 1) or (direction == "j" and end_line >= total_lines) then
		return
	end

	vim.cmd("normal! \27")

	if direction == "j" then
		vim.cmd(string.format("silent '<,'>move %d", end_line + 1))
	else
		vim.cmd(string.format("silent '<,'>move %d", start_line - 2))
	end

	vim.cmd("normal! gv=gv")
end

---@param direction "h"|"l"
M.move_text_horizontal = function(direction)
	local action = (direction == "h") and "<" or ">"
	vim.cmd(string.format("normal! gv%sgv", action))
end

return M
