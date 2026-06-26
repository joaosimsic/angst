local M = {}
local logging = require("backend.engines.doktor.logging")
local log = logging.for_module("commands")

local debug_enabled = false

local severity_order = {
	vim.diagnostic.severity.ERROR,
	vim.diagnostic.severity.WARN,
	vim.diagnostic.severity.INFO,
	vim.diagnostic.severity.HINT,
}

local severity_names = {
	[vim.diagnostic.severity.ERROR] = "ERROR",
	[vim.diagnostic.severity.WARN] = "WARN",
	[vim.diagnostic.severity.INFO] = "INFO",
	[vim.diagnostic.severity.HINT] = "HINT",
}

---@param diagnostics vim.Diagnostic[]
---@return table<string, vim.Diagnostic[]>
local function group_by_file(diagnostics)
	local grouped = {}

	for _, diagnostic in ipairs(diagnostics) do
		local bufnr = diagnostic.bufnr
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			local path = vim.api.nvim_buf_get_name(bufnr)
			if path ~= "" then
				path = vim.fn.fnamemodify(path, ":.")
				grouped[path] = grouped[path] or {}
				grouped[path][#grouped[path] + 1] = diagnostic
			end
		end
	end

	return grouped
end

---@param api table
---@return vim.Diagnostic[]
local function doktor_diagnostics(api)
	if not api._scheduler then
		return {}
	end

	local diagnostics = {}
	for _, namespace in pairs(api._scheduler:namespaces()) do
		vim.list_extend(diagnostics, vim.diagnostic.get(nil, { namespace = namespace }))
	end

	return diagnostics
end

---@param api table
---@return string[]
local function diagnostic_lines(api)
	local grouped = group_by_file(doktor_diagnostics(api))
	local files = vim.tbl_keys(grouped)
	table.sort(files)

	local lines = { "Doktor diagnostics" }
	if #files == 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "No diagnostics."
		return lines
	end

	for _, file in ipairs(files) do
		lines[#lines + 1] = ""
		lines[#lines + 1] = file
		table.sort(grouped[file], function(a, b)
			if a.lnum == b.lnum then
				return a.col < b.col
			end
			return a.lnum < b.lnum
		end)

		for _, diagnostic in ipairs(grouped[file]) do
			lines[#lines + 1] = string.format(
				"  %s %d:%d %s",
				severity_names[diagnostic.severity] or "INFO",
				(diagnostic.lnum or 0) + 1,
				(diagnostic.col or 0) + 1,
				diagnostic.message or ""
			)
		end
	end

	return lines
end

---@param api table
---@return integer, integer
local function open_window(api)
	local config = api.get_config()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].filetype = "doktor"
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, diagnostic_lines(api))
	vim.bo[bufnr].modifiable = false

	local width = math.floor(vim.o.columns * config.window.width_ratio)
	local height = math.floor(vim.o.lines * config.window.height_ratio)
	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = config.window.border,
		title = " Doktor ",
		title_pos = "center",
	})

	return bufnr, win
end

---@param api table
function M.setup(api)
	vim.api.nvim_create_user_command("Doktor", function()
		api.toggle()
	end, {})

	vim.api.nvim_create_user_command("DoktorRescan", function(opts)
		api.rescan(opts.args)
	end, {
		nargs = "?",
		complete = "file",
	})

	vim.api.nvim_create_user_command("DoktorStatus", function()
		local status = api.status()
		local queues = status.queues
		local msg = string.format(
			"Doktor queues P0=%d P1=%d P2=%d P3=%d | LSP %d/%d | lint %d/%d | pending LSP filetypes=%d",
			queues[0],
			queues[1],
			queues[2],
			queues[3],
			status.pools.lsp.in_flight,
			status.pools.lsp.concurrency,
			status.pools.lint.in_flight,
			status.pools.lint.concurrency,
			status.pending_lsp
		)
		vim.notify(msg, vim.log.levels.INFO)
	end, {})

	vim.api.nvim_create_user_command("DoktorDebug", function(opts)
		local action = opts.args ~= "" and opts.args or "toggle"

		if action == "toggle" then
			debug_enabled = not debug_enabled
		elseif action == "on" then
			debug_enabled = true
		elseif action == "off" then
			debug_enabled = false
		else
			vim.notify("Usage: DoktorDebug [on|off|toggle]", vim.log.levels.ERROR)
			return
		end

		local level = debug_enabled and "debug" or api.get_config().log_level
		logging.set_threshold_all(level)
		log:info("debug logging " .. (debug_enabled and "enabled" or "disabled"))
	end, {
		nargs = "?",
		complete = function()
			return { "on", "off", "toggle" }
		end,
	})
end

---@param api table
function M.toggle(api)
	if api._window and vim.api.nvim_win_is_valid(api._window) then
		vim.api.nvim_win_close(api._window, true)
		api._window = nil
		api._buffer = nil
		return
	end

	api._buffer, api._window = open_window(api)
end

return M
