local collector = require("frontend.navigation.doktor.window.collector")
local formatter = require("frontend.navigation.doktor.window.formatter")
---@type DoktorCacheState
local State = require("frontend.navigation.doktor.state")

local icons = require("common.icons").diagnostics

local M = {}

---@return string
local function get_dynamic_root()
	local cwd = vim.fn.getcwd()
	local home = os.getenv("HOME") or vim.fn.expand("~")

	if home and cwd:sub(1, #home) == home then
		return "~" .. cwd:sub(#home + 1)
	end

	return cwd
end

---@return string|table
local function get_status_footer()
	local diagnostic_data = collector.get_structured_diagnostics()

	local counts = {
		[vim.diagnostic.severity.ERROR] = 0,
		[vim.diagnostic.severity.WARN] = 0,
		[vim.diagnostic.severity.INFO] = 0,
		[vim.diagnostic.severity.HINT] = 0,
	}

	for _, data in ipairs(diagnostic_data) do
		for _, diag in ipairs(data.diagnostics) do
			if counts[diag.severity] ~= nil then
				counts[diag.severity] = counts[diag.severity] + 1
			end
		end
	end

	local severity_order = {
		{ id = vim.diagnostic.severity.ERROR, icon = icons.error or "E", hl = "DiagnosticError" },
		{ id = vim.diagnostic.severity.WARN, icon = icons.warn or "W", hl = "DiagnosticWarn" },
		{ id = vim.diagnostic.severity.INFO, icon = icons.info or "I", hl = "DiagnosticInfo" },
		{ id = vim.diagnostic.severity.HINT, icon = icons.hint or "H", hl = "DiagnosticHint" },
	}

	local footer_chunks = {
		{ string.format(" Workspace: %s │ ", get_dynamic_root()), "FloatFooter" },
	}

	local has_diags = false
	for _, sev in ipairs(severity_order) do
		local count = counts[sev.id]
		if count > 0 then
			if has_diags then
				table.insert(footer_chunks, { " ", "FloatFooter" })
			end
			table.insert(footer_chunks, { sev.icon, sev.hl })
			table.insert(footer_chunks, { string.format(" %d", count), "FloatFooter" })
			has_diags = true
		end
	end

	if not has_diags then
		table.insert(footer_chunks, { "No issues", "FloatFooter" })
	end

	local status_loaded = State.is_scanning and " │ [LSP] Fetching... " or " │ [LSP] Done. "
	table.insert(footer_chunks, { status_loaded, "FloatFooter" })

	return footer_chunks
end

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

	if State.current_win_id and vim.api.nvim_win_is_valid(State.current_win_id) then
		vim.api.nvim_win_set_config(State.current_win_id, {
			footer = get_status_footer(),
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
		footer = get_status_footer(),
		footer_pos = "right",
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
