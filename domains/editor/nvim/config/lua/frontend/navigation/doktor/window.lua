local M = {}

---@param items DoktorDiagnosticItem[]
---@return integer bufnr, integer win_id
function M.create_floating_navigator(items)
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].filetype = "doktor"

	local render_lines = {}
	for _, item in ipairs(items) do
		local format_string = string.format(
			"[%s] %s:%d:%d -> %s (%s)",
			item.severity:upper(),
			item.filename,
			item.lnum + 1,
			item.col + 1,
			item.message,
			item.source or "Linter"
		)
		table.insert(render_lines, format_string)
	end
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, render_lines)

	local screen_width = vim.o.columns
	local screen_height = vim.o.lines
	local win_width = math.ceil(screen_width * 0.8)
	local win_height = math.ceil(screen_height * 0.7)

	local win_opts = {
		relative = "editor",
		width = win_width,
		height = win_height,
		col = math.ceil((screen_width - win_width) / 2),
		row = math.ceil((screen_height - win_height) / 2),
		style = "minimal",
		border = "rounded",
		title = " Doktor's Diagnostics ",
		title_pos = "center",
	}

	local win_id = vim.api.nvim_open_win(bufnr, true, win_opts)

	return bufnr, win_id
end

return M
