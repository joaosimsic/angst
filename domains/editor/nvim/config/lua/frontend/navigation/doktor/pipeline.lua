local async = require("plenary.async")
local Scanner = require("backend.shared.AdapterScanner")
local State = require("frontend.navigation.doktor.state")

local M = {}

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
	if State.state.is_scanning then
		return
	end

	State.state.is_scanning = true

	for _, ft in ipairs(Scanner:supported_filetypes("lsp", {})) do
		State.state.target_extensions[ft] = true
	end

	async.run(function()
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
		State.state.items = aggregated_items
		State.state.is_scanning = false

		async.util.scheduler()
		return aggregated_items
	end, function(aggregated_items)
		callback(aggregated_items)
	end)
end

return M
