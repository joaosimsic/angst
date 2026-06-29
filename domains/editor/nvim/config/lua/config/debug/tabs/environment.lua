local AdapterScanner = require("backend.shared.AdapterScanner")
local state = require("config.debug.state")

local M = {}

local CARD_WIDTH = 84
local LABEL_WIDTH = 20
local VALUE_WIDTH = CARD_WIDTH - LABEL_WIDTH - 5
local ENGINES = { "lsp", "treesitter", "formatter", "linter" }

local function ellipsize(value, width)
	value = tostring(value or "")

	if #value <= width then
		return value
	end

	if width <= 1 then
		return string.sub(value, 1, width)
	end

	return string.sub(value, 1, width - 1) .. "..."
end

local function join_or_none(values, none)
	if not values or #values == 0 then
		return none or "none"
	end

	return table.concat(values, ", ")
end

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

local function add_highlight(view, line, group, start_col, end_col)
	table.insert(view.highlights, {
		line = line,
		group = group,
		start_col = start_col,
		end_col = end_col,
	})
end

local function add_line(view, text)
	table.insert(view.lines, text)
	return #view.lines
end

local function add_gap(view)
	add_line(view, "")
end

local function add_section(view, title)
	local prefix = "+-- " .. title .. " "
	local line = prefix .. string.rep("-", math.max(0, CARD_WIDTH - #prefix - 1)) .. "+"
	local line_nr = add_line(view, line)

	add_highlight(view, line_nr, "DebugBorder", 0, -1)
	add_highlight(view, line_nr, "DebugHeader", 4, 4 + #title)
end

local function add_footer(view)
	local line_nr = add_line(view, "+" .. string.rep("-", CARD_WIDTH - 2) .. "+")
	add_highlight(view, line_nr, "DebugBorder", 0, -1)
end

local function add_row(view, label, value, value_hl)
	label = ellipsize(label, LABEL_WIDTH)
	value = ellipsize(value, VALUE_WIDTH)

	local line = string.format("| %-" .. LABEL_WIDTH .. "s %-" .. VALUE_WIDTH .. "s |", label, value)
	local line_nr = add_line(view, line)
	local value_start = 2 + LABEL_WIDTH + 1

	add_highlight(view, line_nr, "DebugBorder", 0, 1)
	add_highlight(view, line_nr, "DebugBorder", #line - 1, #line)
	add_highlight(view, line_nr, "DebugLabel", 2, 2 + #label)
	add_highlight(view, line_nr, value_hl or "DebugValue", value_start, value_start + #value)
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

local function add_runtime_section(view)
	add_section(view, "Runtime")
	add_row(view, "CWD", vim.fn.getcwd(), "DebugValue")
	add_row(view, "Neovim", nvim_version(), "DebugInfo")
	add_row(view, "Config path", stdpath("config"), "DebugValue")
	add_row(view, "Data path", stdpath("data"), "DebugValue")
	add_row(view, "Cache path", stdpath("cache"), "DebugValue")
	add_row(view, "State path", stdpath("state"), "DebugValue")
	add_row(view, "Colorscheme", vim.g.colors_name or "none", vim.g.colors_name and "DebugInfo" or "DebugMuted")
	add_row(view, "Shell", vim.o.shell, "DebugValue")
	add_footer(view)
end

local function add_debug_window_section(view, bufnr)
	local name, name_hl = buffer_name(bufnr)
	local width = state.win and vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_width(state.win) or nil
	local height = state.win and vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_height(state.win) or nil
	local size = width and height and string.format("%dx%d", width, height) or "closed"

	add_section(view, "Debug Window")
	add_row(view, "Origin buffer", bufnr or "none", bufnr and "DebugInfo" or "DebugWarn")
	add_row(view, "Filetype", buffer_filetype(bufnr), bufnr and "DebugOk" or "DebugWarn")
	add_row(view, "Name", name, name_hl)
	add_row(view, "Current tab", state.current_tab or "unknown", "DebugInfo")
	add_row(view, "Window size", size, width and "DebugInfo" or "DebugMuted")
	add_footer(view)
end

local function add_engines_section(view)
	local adapters = safe_call(function()
		return AdapterScanner:adapters()
	end, {})

	add_section(view, "Engines")
	add_row(view, "Adapters", count_table(adapters), count_table(adapters) > 0 and "DebugOk" or "DebugWarn")

	for _, engine in ipairs(ENGINES) do
		local configured, executable, filetypes = engine_counts(engine)
		local value = string.format("tools %s | executable %s | filetypes %d", configured, executable, filetypes)
		local hl = configured > 0 and "DebugInfo" or "DebugMuted"
		add_row(view, engine, value, hl)
	end

	add_footer(view)
end

local function add_current_buffer_section(view, bufnr)
	local ft = buffer_filetype(bufnr)
	local lang = vim.treesitter.language.get_lang(ft) or ft
	local parser = active_treesitter_parser(bufnr)
	local queries = query_count(lang)

	add_section(view, "Current Buffer")
	add_row(view, "Filetype", ft, ft == "unsupported" and "DebugWarn" or "DebugOk")
	add_row(view, "LSP", join_or_none(tools_for_filetype("lsp", ft, false), "none configured"), "DebugValue")
	add_row(view, "Formatters", join_or_none(tools_for_filetype("formatter", ft, false), "none configured"), "DebugValue")
	add_row(view, "Linters", join_or_none(tools_for_filetype("linter", ft, false), "none configured"), "DebugValue")
	add_row(view, "Tree-sitter", lang, lang ~= "unsupported" and "DebugInfo" or "DebugWarn")
	add_row(view, "Highlighter", parser and "active" or "inactive", parser and "DebugOk" or "DebugWarn")
	add_row(view, "Query files", queries, queries > 0 and "DebugOk" or "DebugWarn")

	local missing = {}
	for _, engine in ipairs({ "lsp", "formatter", "linter" }) do
		for _, tool in ipairs(missing_tools(engine, ft)) do
			table.insert(missing, engine .. ":" .. tool)
		end
	end

	add_row(view, "Missing binaries", join_or_none(missing, "none"), #missing == 0 and "DebugOk" or "DebugWarn")
	add_footer(view)
end

local function add_doktor_section(view)
	local ok, config = pcall(require, "backend.engines.doktor.config")
	local doktor = ok and config.get() or nil

	add_section(view, "Doktor")

	if not doktor then
		add_row(view, "Status", "config unavailable", "DebugWarn")
		add_footer(view)
		return
	end

	add_row(view, "Debounce", tostring(doktor.debounce_ms) .. "ms", "DebugInfo")
	add_row(view, "Idle", tostring(doktor.idle_ms) .. "ms", "DebugInfo")
	add_row(view, "Max hidden buffers", doktor.max_hidden_buffers, "DebugInfo")
	add_row(view, "Cache path", doktor.cache_path, "DebugValue")
	add_row(view, "Log level", doktor.log_level, "DebugInfo")
	add_row(view, "Notify on error", bool_label(doktor.notify_on_error), doktor.notify_on_error and "DebugOk" or "DebugMuted")
	add_row(view, "LSP timeout", tostring(doktor.lsp_timeout_ms) .. "ms", "DebugInfo")
	add_row(view, "Concurrency", string.format("lsp %s | lint %s", doktor.concurrency.lsp, doktor.concurrency.lint), "DebugInfo")
	add_row(
		view,
		"Bootstrap",
		string.format("enter %s | tick %s", bool_label(doktor.bootstrap.on_vim_enter), doktor.bootstrap.max_files_per_tick),
		"DebugInfo"
	)
	add_row(
		view,
		"Window",
		string.format("%sx%s | %s", doktor.window.width_ratio, doktor.window.height_ratio, doktor.window.border),
		"DebugInfo"
	)
	add_footer(view)
end

---@param bufnr integer
---@return { lines: string[], highlights: table[] }
function M.render(bufnr)
	local view = {
		lines = {},
		highlights = {},
	}

	add_runtime_section(view)
	add_gap(view)
	add_debug_window_section(view, bufnr)
	add_gap(view)
	add_engines_section(view)
	add_gap(view)
	add_current_buffer_section(view, bufnr)
	add_gap(view)
	add_doktor_section(view)

	return view
end

return M
