local M = {}

---@param direction "j"|"k"
M.move_text_vertical = function(direction)
	vim.cmd([[:execute "silent! normal! \<ESC>"]])

	if direction == "j" then
		vim.cmd("silent! '<,'>move '>+1")
	elseif direction == "k" then
		vim.cmd("silent! '<,'>move '<-2")
	end

	vim.cmd("silent! normal! gv")
end

---@param direction "h"|"l"
M.move_text_horizontal = function(direction)
	local sw = vim.o.shiftwidth

	if sw == 0 then
		sw = vim.bo.tabstop
	end

	if sw == 0 then
		sw = 4
	end

	if direction == "h" then
		local start_line = vim.fn.line("'<")
		local end_line = vim.fn.line("'>")

		local hit_wall = false
		for i = start_line, end_line do
			local line_text = vim.fn.getline(i)
			if line_text:match("^[^%s]") then
				hit_wall = true
				break
			end
		end

		if hit_wall then
			vim.cmd("normal! gv")
			return
		end
	end

	local action = (direction == "h") and "<" or ">"
	vim.cmd(string.format("silent! normal! %sgv", action))
end

return M
