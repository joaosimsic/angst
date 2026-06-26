---@type DoktorCacheState
local State = require("frontend.navigation.doktor.state")
local collector = require("frontend.navigation.doktor.window.collector")
local formatter = require("frontend.navigation.doktor.window.formatter")
---@type Logger
local logger = require("frontend.navigation.doktor.logger")

---@type DiagnosticIcons
local icons = require("common.icons").diagnostics

local M = {}

---@return string
local function get_dynamic_root()
	---@type string
	local cwd = vim.fn.getcwd()
	---@type string|nil
	local home = os.getenv("HOME") or vim.fn.expand("~")

	if home and cwd:sub(1, #home) == home then
		return "~" .. cwd:sub(#home + 1)
	end

	return cwd
end

---@return { [1]: string, [2]: string }[]
local function get_status_footer()
	---@type table<string, DoktorGroupedFile>
	local diagnostic_data = collector.get_structured_diagnostics()

	---@type table<vim.diagnostic.Severity, integer>
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

	---@type {id: vim.diagnostic.Severity, icon: string, hl: string}[]
	local severity_order = {
		{ id = vim.diagnostic.severity.ERROR, icon = icons.error or "E", hl = "DiagnosticError" },
		{ id = vim.diagnostic.severity.WARN, icon = icons.warn or "W", hl = "DiagnosticWarn" },
		{ id = vim.diagnostic.severity.INFO, icon = icons.info or "I", hl = "DiagnosticInfo" },
		{ id = vim.diagnostic.severity.HINT, icon = icons.hint or "H", hl = "DiagnosticHint" },
	}

	---@type { [1]: string, [2]: string }[]
	local footer_chunks = {
		{ string.format(" Workspace: %s │ ", get_dynamic_root()), "FloatFooter" },
	}

	---@type boolean
	local has_diags = false
	for _, sev in ipairs(severity_order) do
		---@type integer
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

	---@type string
	local status_loaded = State.is_scanning and " │ [LSP] Fetching... " or " │ [LSP] Done. "
	table.insert(footer_chunks, { status_loaded, "FloatFooter" })

	return footer_chunks
end

---@param bufnr integer
---@return nil
function M.update_buffer_contents(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	---@type table<string, DoktorGroupedFile>
	local diagnostic_data = collector.get_structured_diagnostics()
	---@type string[]
	local lines
	---@type DoktorTreeHighlight[]
	local highlights
	lines, highlights = formatter.build_tree_view(diagnostic_data)

	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false

	---@type integer
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

	logger:debug(function()
		return string.format("Window buffer updated: %d lines, %d highlights", #lines, #highlights)
	end)
end

---@return integer
---@return integer
function M.render_diagnostics_window()
	if State.current_win_id and vim.api.nvim_win_is_valid(State.current_win_id) then
		M.update_buffer_contents(State.current_bufnr)
		vim.api.nvim_set_current_win(State.current_win_id)
		logger:debug(function()
			return "Window refreshed"
		end)
		return State.current_bufnr, State.current_win_id
	end

	---@type integer
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].filetype = "diagnostic-menu"

	M.update_buffer_contents(bufnr)

	---@type DoktorWindowConfig
	local win_config = State.config.window

	---@type integer
	local width = math.floor(vim.o.columns * win_config.width_ratio)
	---@type integer
	local height = math.floor(vim.o.lines * win_config.height_ratio)

	---@type integer
	local win_id = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = win_config.border,
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

	logger:info(function()
		return string.format("Window opened: buf=%d, win=%d", bufnr, win_id)
	end)

	return bufnr, win_id
end

return M
