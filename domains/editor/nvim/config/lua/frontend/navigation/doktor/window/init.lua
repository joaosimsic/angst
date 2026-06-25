local collector = require("frontend.navigation.doktor.window.collector")
local formatter = require("frontend.navigation.doktor.window.formatter")
---@type DoktorCacheState
local State = require("frontend.navigation.doktor.state")

local M = {}

function M.update_buffer_contents(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local diagnostic_data = collector.get_structured_diagnostics()
	local lines, highlights = formatter.build_tree_view(diagnostic_data)

	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false

	local ns_id = vim.api.nvim_create_namespace("DiagnosticWindowIcons")
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, hl.line, hl.start_col, {
			end_col = hl.end_col,
			hl_group = hl.hl,
			hl_mode = "combine",
		})
	end
end

function M.render_diagnostics_window()
	if State.current_win_id and vim.api.nvim_win_is_valid(State.current_win_id) then
		M.update_buffer_contents(State.current_bufnr)
		vim.api.nvim_set_current_win(State.current_win_id)
		return State.current_bufnr, State.current_win_id
	end

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].filetype = "diagnostic-menu"

	M.update_buffer_contents(bufnr)

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

	State.current_bufnr = bufnr
	State.current_win_id = win_id

	vim.api.nvim_buf_attach(bufnr, false, {
		on_detach = function()
			State.current_bufnr = nil
			State.current_win_id = nil
		end,
	})

	return bufnr, win_id
end

return M
