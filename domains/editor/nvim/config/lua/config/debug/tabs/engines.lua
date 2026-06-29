local AdapterScanner = require("backend.shared.AdapterScanner")

local M = {}

local CARD_WIDTH = 84
local LABEL_WIDTH = 20
local VALUE_WIDTH = CARD_WIDTH - LABEL_WIDTH - 5
local QUERY_GROUPS = { "highlights", "injections", "locals", "folds", "indents" }

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

local function buffer_name(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)

	if name == "" then
		return "[No name]", "DebugMuted"
	end

	return vim.fn.fnamemodify(name, ":~:."), "DebugValue"
end

local function client_root(client)
	if client.config and client.config.root_dir then
		return vim.fn.fnamemodify(client.config.root_dir, ":~:.")
	end

	if client.workspace_folders and client.workspace_folders[1] then
		return vim.fn.fnamemodify(client.workspace_folders[1].name, ":~:.")
	end

	return "no root"
end

local function add_tools_section(view, title, engine, ft)
	local configured = AdapterScanner:tools_for_filetype(engine, ft, { check_executable = false })
	local available = AdapterScanner:tools_for_filetype(engine, ft, { check_executable = true })
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

	add_section(view, title)

	if #configured == 0 then
		add_row(view, "Configured", "none for this filetype", "DebugMuted")
	else
		add_row(
			view,
			"Available",
			join_or_none(available, "none executable"),
			#available > 0 and "DebugOk" or "DebugWarn"
		)

		if #missing > 0 then
			add_row(view, "Missing binaries", table.concat(missing, ", "), "DebugWarn")
		end
	end

	add_footer(view)
end

local function collect_parser_langs(parser)
	local langs = {}
	local seen = {}

	local function add_lang(lang)
		if type(lang) == "string" and lang ~= "" and not seen[lang] then
			seen[lang] = true
			table.insert(langs, lang)
		end
	end

	local function visit(tree)
		local ok_lang, lang = pcall(function()
			return tree:lang()
		end)

		if ok_lang then
			add_lang(lang)
		end

		local ok_children, children = pcall(function()
			return tree:children()
		end)

		if not ok_children or type(children) ~= "table" then
			return
		end

		for child_lang, child in pairs(children) do
			add_lang(child_lang)
			visit(child)
		end
	end

	if parser then
		visit(parser)
	end

	table.sort(langs)
	return langs
end

local function active_treesitter_parser(bufnr)
	local active_highlighters = vim.treesitter.highlighter and vim.treesitter.highlighter.active
	local highlighter = active_highlighters and active_highlighters[bufnr]

	if not highlighter then
		return nil
	end

	return highlighter.tree
end

local function query_source(path)
	local name = vim.fn.fnamemodify(path, ":t")

	if path:find(".local/share/tree-sitter", 1, true) then
		return "custom/" .. name
	end

	return vim.fn.fnamemodify(path, ":h:t") .. "/" .. name
end

local function query_summary(lang)
	local parts = {}
	local detail = {}

	for _, group in ipairs(QUERY_GROUPS) do
		local ok, files = pcall(vim.treesitter.query.get_files, lang, group)

		if ok and files and #files > 0 then
			table.insert(parts, string.format("%s:%d", group, #files))

			local sources = {}
			for _, path in ipairs(files) do
				table.insert(sources, query_source(path))
			end

			table.insert(detail, {
				group = group,
				value = table.concat(sources, ", "),
			})
		end
	end

	return parts, detail
end

---@param bufnr integer
---@return { lines: string[], highlights: table[] }
function M.render(bufnr)
	local ft = vim.bo[bufnr].filetype
	if ft == "" then
		ft = "unsupported"
	end

	local view = {
		lines = {},
		highlights = {},
	}

	local name, name_hl = buffer_name(bufnr)

	add_section(view, "Buffer")
	add_row(view, "Buffer", bufnr, "DebugInfo")
	add_row(view, "Filetype", ft, ft == "unsupported" and "DebugWarn" or "DebugOk")
	add_row(view, "Name", name, name_hl)
	add_footer(view)
	add_gap(view)

	add_section(view, "LSP")
	local lsp_clients = vim.lsp.get_clients({ bufnr = bufnr })

	if #lsp_clients == 0 then
		add_row(view, "Active clients", "none attached", "DebugMuted")
	else
		add_row(view, "Active clients", #lsp_clients, "DebugOk")
	end

	for _, client in ipairs(lsp_clients) do
		add_row(view, client.name, string.format("id %d | %s", client.id, client_root(client)), "DebugInfo")
	end

	add_footer(view)
	add_gap(view)

	add_section(view, "Tree-sitter")
	local treesitter_opts = { check_executable = false }
	local supported = AdapterScanner:supports_filetype("treesitter", ft, treesitter_opts)
	local lang = vim.treesitter.language.get_lang(ft) or ft
	local parser = active_treesitter_parser(bufnr)
	local active_langs = collect_parser_langs(parser)

	add_row(view, "Supported", supported and "yes" or "no adapter", supported and "DebugOk" or "DebugWarn")
	add_row(view, "Resolved parser", lang, supported and "DebugInfo" or "DebugMuted")
	add_row(view, "Highlighter", parser and "active" or "inactive", parser and "DebugOk" or "DebugWarn")
	add_row(
		view,
		"Active parsers",
		join_or_none(active_langs, "none attached"),
		#active_langs > 0 and "DebugOk" or "DebugMuted"
	)
	add_footer(view)
	add_gap(view)

	add_section(view, "Tree-sitter Queries")
	local query_langs = #active_langs > 0 and active_langs or { lang }

	for _, query_lang in ipairs(query_langs) do
		local parts, detail = query_summary(query_lang)

		add_row(view, query_lang, join_or_none(parts, "no query files found"), #parts > 0 and "DebugOk" or "DebugWarn")

		for _, item in ipairs(detail) do
			add_row(
				view,
				"  " .. item.group,
				item.value,
				item.value:find("custom/", 1, true) and "DebugInfo" or "DebugValue"
			)
		end
	end

	add_footer(view)
	add_gap(view)

	add_tools_section(view, "Formatters", "formatter", ft)
	add_gap(view)
	add_tools_section(view, "Linters", "linter", ft)

	return view
end

return M
