local collector = require("frontend.navigation.doktor.window.collector")
local formatter = require("frontend.navigation.doktor.window.formatter")

local M = {}

function M.render_diagnostics_window()
	local diagnostic_data = collector.get_structured_diagnostics()
	local lines, highlights = formatter.build_tree_view(diagnostic_data)

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].filetype = "diagnostic-menu"
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	local ns_id = vim.api.nvim_create_namespace("DiagnosticWindowIcons")
	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, hl.line, hl.start_col, {
			end_col = hl.end_col,
			hl_group = hl.hl,
			hl_mode = "combine",
		})
	end

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.6)

	local win_id = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " Doktor's Diagnostics ",
		title_pos = "center",
	})

	return bufnr, win_id
end

return M
