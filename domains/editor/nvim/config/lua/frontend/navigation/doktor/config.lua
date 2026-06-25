local async = require("plenary.async")
---@type AdapterScanner
local Scanner = require("backend.shared.AdapterScanner")

---@class DoktorConfigEngine
---@field state DoktorCacheState
local M = {}

M.state = {
	items = {},
	target_extensions = {},
	is_scanning = false,
}

---@param severity_id vim.diagnostic.Severity
---@return DoktorDiagnosticSeverity
local function normalize_severity(severity_id)
	local severities = {
		[vim.diagnostic.severity.ERROR] = "Error",
		[vim.diagnostic.severity.WARN] = "Warning",
		[vim.diagnostic.severity.INFO] = "Information",
		[vim.diagnostic.severity.HINT] = "Hint",
	}

	return severities[severity_id] or "Hint"
end

---@param bufnr integer
---@return DoktorDiagnosticItem[]
function M.fetch_inline_diagnostics(bufnr)
	local file_path = vim.api.nvim_buf_get_name(bufnr)

	if file_path == "" then
		return {}
	end

	local raw_diagnostics = vim.diagnostic.get(bufnr)

	---@type DoktorDiagnosticItem[]
	local collected = {}

	for _, diag in ipairs(raw_diagnostics) do
		table.insert(collected, {
			filename = vim.fn.fnamemodify(file_path, ":."),
			lnum = diag.lnum,
			col = diag.col,
			message = diag.message,
			severity = normalize_severity(diag.severity),
			source = diag.source,
		})
	end

	return collected
end

---@param callback fun(items: DoktorDiagnosticItem[])
function M.trigger_async_diagnostic_pipeline(callback)
	if M.state.is_scanning then
		return
	end

	M.state.is_scanning = true

	for _, ft in ipairs(Scanner:supported_filetypes("lsp", {})) do
		M.state.target_extensions[ft] = true
	end

	async.run(function()
		---@type DoktorDiagnosticItem[]
		local aggregated_items = {}

		local active_buffers = vim.api.nvim_list_bufs()

		for _, bufnr in ipairs(active_buffers) do
			if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
				local inline_items = M.fetch_inline_diagnostics(bufnr)

				for _, item in ipairs(inline_items) do
					table.insert(aggregated_items, item)
				end
			end
		end

		async.util.sleep(10)

		M.state.items = aggregated_items
		M.state.is_scanning = false

		async.util.scheduler()

		return aggregated_items
	end, function(aggregated_items)
		callback(aggregated_items)
	end)
end

---@param items DoktorDiagnosticItem[]
---@return integer bufnr, integer win_id
function M.create_floating_navigator(items)
	local bufnr = vim.api.nvim_create_buf(false, true)

	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].filetype = "doktor"

	---@type string[]
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
		title = " Asynchronous Doktor Diagnostic Navigator ",
		title_pos = "center",
	}

	local win_id = vim.api.nvim_open_win(bufnr, true, win_opts)

	return bufnr, win_id
end

return M
