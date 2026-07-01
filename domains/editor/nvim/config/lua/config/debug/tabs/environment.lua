local R = require("config.debug.render")
local AdapterScanner = require("backend.shared.AdapterScanner")
local state = require("config.debug.state")

local M = {}

local ENGINES = { "lsp", "treesitter", "formatter", "linter" }

local function bool_label(value)
	return value and "yes" or "no"
end

local function count_table(value)
	if type(value) ~= "table" then
		return 0
	end

	local count = 0
	for _ in pairs(value) do
		count = count + 1
	end

	return count
end

local function safe_call(fn, fallback)
	local ok, result = pcall(fn)

	if ok then
		return result
	end

	return fallback
end

local function stdpath(name)
	return safe_call(function()
		return vim.fn.stdpath(name)
	end, "unavailable")
end

local function buffer_name(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return "[No buffer]", "DebugWarn"
	end

	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return "[No name]", "DebugMuted"
	end

	return vim.fn.fnamemodify(name, ":~:."), "DebugValue"
end

local function buffer_filetype(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return "unsupported"
	end

	local ft = vim.bo[bufnr].filetype
	if ft == "" then
		return "unsupported"
	end

	return ft
end

local function nvim_version()
	local version = safe_call(vim.version, nil)
	if type(version) ~= "table" then
		return "unknown"
	end

	return string.format("%d.%d.%d", version.major or 0, version.minor or 0, version.patch or 0)
end

local function active_treesitter_parser(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return nil
	end

	local active_highlighters = vim.treesitter.highlighter and vim.treesitter.highlighter.active
	local highlighter = active_highlighters and active_highlighters[bufnr]

	if not highlighter then
		return nil
	end

	return highlighter.tree
end

local function query_count(lang)
	local count = 0
	for _, group in ipairs({ "highlights", "injections", "locals", "folds", "indents" }) do
		local files = safe_call(function()
			return vim.treesitter.query.get_files(lang, group)
		end, nil)

		if type(files) == "table" then
			count = count + #files
		end
	end

	return count
end

local function tools_for_filetype(engine, ft, check_executable)
	return safe_call(function()
		return AdapterScanner:tools_for_filetype(engine, ft, { check_executable = check_executable })
	end, {})
end

local function missing_tools(engine, ft)
	local configured = tools_for_filetype(engine, ft, false)
	local available = tools_for_filetype(engine, ft, true)
	local available_set = {}
	local missing = {}

	for _, tool in ipairs(available) do
		available_set[tool] = true
	end

	for _, tool in ipairs(configured) do
		if not available_set[tool] then
			table.insert(missing, tool)
		end
	end

	return missing
end

local function engine_counts(engine)
	local configured = safe_call(function()
		return AdapterScanner:by_tool(engine, { check_executable = false })
	end, {})
	local filetypes = safe_call(function()
		return AdapterScanner:supported_filetypes(engine, { check_executable = false })
	end, {})

	if engine == "treesitter" then
		return count_table(configured), "not checked", #filetypes
	end

	local executable = safe_call(function()
		return AdapterScanner:by_tool(engine, { check_executable = true })
	end, {})

	return count_table(configured), count_table(executable), #filetypes
end

local function add_runtime_section(view, card_width)
	R.add_section(view, "Runtime", card_width)
	R.add_row(view, "CWD", vim.fn.getcwd(), "DebugValue")
	R.add_row(view, "Neovim", nvim_version(), "DebugInfo")
	R.add_row(view, "Config path", stdpath("config"), "DebugValue")
	R.add_row(view, "Data path", stdpath("data"), "DebugValue")
	R.add_row(view, "Cache path", stdpath("cache"), "DebugValue")
	R.add_row(view, "State path", stdpath("state"), "DebugValue")
	R.add_row(view, "Colorscheme", vim.g.colors_name or "none", vim.g.colors_name and "DebugInfo" or "DebugMuted")
	R.add_row(view, "Shell", vim.o.shell, "DebugValue")
	R.add_footer(view, card_width)
end

local function add_debug_window_section(view, bufnr, card_width)
	local name, name_hl = buffer_name(bufnr)
	local width = state.win and vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_width(state.win) or nil
	local height = state.win and vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_height(state.win) or nil
	local size = width and height and string.format("%dx%d", width, height) or "closed"

	R.add_section(view, "Debug Window", card_width)
	R.add_row(view, "Origin buffer", bufnr or "none", bufnr and "DebugInfo" or "DebugWarn")
	R.add_row(view, "Filetype", buffer_filetype(bufnr), bufnr and "DebugOk" or "DebugWarn")
	R.add_row(view, "Name", name, name_hl)
	R.add_row(view, "Current tab", state.current_tab or "unknown", "DebugInfo")
	R.add_row(view, "Window size", size, width and "DebugInfo" or "DebugMuted")
	R.add_footer(view, card_width)
end

local function add_engines_section(view, card_width)
	local adapters = safe_call(function()
		return AdapterScanner:adapters()
	end, {})

	R.add_section(view, "Engines", card_width)
	R.add_row(view, "Adapters", count_table(adapters), count_table(adapters) > 0 and "DebugOk" or "DebugWarn")

	for _, engine in ipairs(ENGINES) do
		local configured, executable, filetypes = engine_counts(engine)
		local value = string.format("tools %s | executable %s | filetypes %d", configured, executable, filetypes)
		local hl = configured > 0 and "DebugInfo" or "DebugMuted"
		R.add_row(view, engine, value, hl)
	end

	R.add_footer(view, card_width)
end

local function add_current_buffer_section(view, bufnr, card_width)
	local ft = buffer_filetype(bufnr)
	local lang = vim.treesitter.language.get_lang(ft) or ft
	local parser = active_treesitter_parser(bufnr)
	local queries = query_count(lang)

	R.add_section(view, "Current Buffer", card_width)
	R.add_row(view, "Filetype", ft, ft == "unsupported" and "DebugWarn" or "DebugOk")
	R.add_row(view, "LSP", R.join_or_none(tools_for_filetype("lsp", ft, false), "none configured"), "DebugValue")
	R.add_row(view, "Formatters", R.join_or_none(tools_for_filetype("formatter", ft, false), "none configured"), "DebugValue")
	R.add_row(view, "Linters", R.join_or_none(tools_for_filetype("linter", ft, false), "none configured"), "DebugValue")
	R.add_row(view, "Tree-sitter", lang, lang ~= "unsupported" and "DebugInfo" or "DebugWarn")
	R.add_row(view, "Highlighter", parser and "active" or "inactive", parser and "DebugOk" or "DebugWarn")
	R.add_row(view, "Query files", queries, queries > 0 and "DebugOk" or "DebugWarn")

	local missing = {}
	for _, engine in ipairs({ "lsp", "formatter", "linter" }) do
		for _, tool in ipairs(missing_tools(engine, ft)) do
			table.insert(missing, engine .. ":" .. tool)
		end
	end

	R.add_row(view, "Missing binaries", R.join_or_none(missing, "none"), #missing == 0 and "DebugOk" or "DebugWarn")
	R.add_footer(view, card_width)
end

local function add_doktor_section(view, card_width)
	local ok, config = pcall(require, "backend.engines.doktor.config")
	local doktor = ok and config.get() or nil

	R.add_section(view, "Doktor", card_width)

	if not doktor then
		R.add_row(view, "Status", "config unavailable", "DebugWarn")
		R.add_footer(view, card_width)
		return
	end

	R.add_row(view, "Debounce", tostring(doktor.debounce_ms) .. "ms", "DebugInfo")
	R.add_row(view, "Idle", tostring(doktor.idle_ms) .. "ms", "DebugInfo")
	R.add_row(view, "Max hidden buffers", doktor.max_hidden_buffers, "DebugInfo")
	R.add_row(view, "Cache path", doktor.cache_path, "DebugValue")
	R.add_row(view, "Log level", doktor.log_level, "DebugInfo")
	R.add_row(view, "Notify on error", bool_label(doktor.notify_on_error), doktor.notify_on_error and "DebugOk" or "DebugMuted")
	R.add_row(view, "LSP timeout", tostring(doktor.lsp_timeout_ms) .. "ms", "DebugInfo")
	R.add_row(view, "Concurrency", string.format("lsp %s | lint %s", doktor.concurrency.lsp, doktor.concurrency.lint), "DebugInfo")
	R.add_row(
		view,
		"Bootstrap",
		string.format("enter %s | tick %s", bool_label(doktor.bootstrap.on_vim_enter), doktor.bootstrap.max_files_per_tick),
		"DebugInfo"
	)
	R.add_row(
		view,
		"Window",
		string.format("%sx%s | %s", doktor.window.width_ratio, doktor.window.height_ratio, doktor.window.border),
		"DebugInfo"
	)
	R.add_footer(view, card_width)
end

---@param bufnr integer
---@param card_width? integer
---@return { lines: string[], highlights: table[] }
function M.render(bufnr, card_width)
	card_width = card_width or 84
	R.set_card_width(card_width)

	local view = {
		lines = {},
		highlights = {},
	}

	add_runtime_section(view, card_width)
	R.add_gap(view)
	add_debug_window_section(view, bufnr, card_width)
	R.add_gap(view)
	add_engines_section(view, card_width)
	R.add_gap(view)
	add_current_buffer_section(view, bufnr, card_width)
	R.add_gap(view)
	add_doktor_section(view, card_width)

	return view
end

return M
