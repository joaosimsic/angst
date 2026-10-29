local R = require("config.debug.render")
local AdapterScanner = require("backend.shared.AdapterScanner")

local M = {}

local QUERY_GROUPS = { "highlights", "injections", "locals", "folds", "indents" }

local function count_label(name, count)
	return string.format("%s (%d)", name, count)
end

local function buffer_name(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)

	if name == "" then
		return "[No name]", "DebugMuted"
	end

	return vim.fn.fnamemodify(name, ":~:."), "DebugValue"
end

local function client_root(client)
	if client.root_dir then
		return vim.fn.fnamemodify(client.root_dir, ":~:.")
	end

	if client.config and client.config.root_dir then
		return vim.fn.fnamemodify(client.config.root_dir, ":~:.")
	end

	if client.workspace_folders and client.workspace_folders[1] then
		return vim.fn.fnamemodify(client.workspace_folders[1].name, ":~:.")
	end

	return "no root"
end

local function add_tools_section(view, title, engine, ft, card_width)
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

	R.add_section(view, title, card_width)

	if #configured == 0 then
		R.add_row(view, "Configured", "none for this filetype", "DebugMuted")
	else
		R.add_row(view, "Configured", R.join_or_none(configured), "DebugValue")
		R.add_row(
			view,
			"Executable",
			R.join_or_none(available, "none executable"),
			#available > 0 and "DebugOk" or "DebugWarn"
		)

		if #missing > 0 then
			R.add_row(view, "Missing binaries", table.concat(missing, ", "), "DebugWarn")
		end
	end

	R.add_footer(view, card_width)
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
			table.insert(parts, count_label(group, #files))

			local sources = {}
			for _, path in ipairs(files) do
				table.insert(sources, query_source(path))
			end

			table.insert(detail, {
				group = group,
				sources = sources,
			})
		end
	end

	return parts, detail
end

---@param bufnr integer
---@param card_width? integer
---@return { lines: string[], highlights: table[] }
function M.render(bufnr, card_width)
	card_width = card_width or 84
	R.set_card_width(card_width)

	local ft = vim.bo[bufnr].filetype
	if ft == "" then
		ft = "unsupported"
	end

	local view = {
		lines = {},
		highlights = {},
	}

	local name, name_hl = buffer_name(bufnr)

	R.add_section(view, "Buffer", card_width)
	R.add_row(view, "Buffer", bufnr, "DebugInfo")
	R.add_row(view, "Filetype", ft, ft == "unsupported" and "DebugWarn" or "DebugOk")
	R.add_row(view, "Name", name, name_hl)
	R.add_footer(view, card_width)
	R.add_gap(view)

	R.add_section(view, "LSP", card_width)
	local lsp_clients = vim.lsp.get_clients({ bufnr = bufnr })

	if #lsp_clients == 0 then
		R.add_row(view, "Active clients", "none attached", "DebugMuted")
	else
		R.add_row(view, "Active clients", #lsp_clients, "DebugOk")
	end

	for _, client in ipairs(lsp_clients) do
		R.add_row(view, client.name, string.format("id %d | %s", client.id, client_root(client)), "DebugInfo")
	end

	R.add_footer(view, card_width)
	R.add_gap(view)

	R.add_section(view, "Tree-sitter", card_width)
	local treesitter_opts = { check_executable = false }
	local supported = AdapterScanner:supports_filetype("treesitter", ft, treesitter_opts)
	local lang = vim.treesitter.language.get_lang(ft) or ft
	local parser = active_treesitter_parser(bufnr)
	local active_langs = collect_parser_langs(parser)

	R.add_row(view, "Supported", supported and "yes" or "no adapter", supported and "DebugOk" or "DebugWarn")
	R.add_row(view, "Resolved parser", lang, supported and "DebugInfo" or "DebugMuted")
	R.add_row(view, "Highlighter", parser and "active" or "inactive", parser and "DebugOk" or "DebugWarn")
	R.add_row(
		view,
		"Active parsers",
		R.join_or_none(active_langs, "none attached"),
		#active_langs > 0 and "DebugOk" or "DebugMuted"
	)
	R.add_footer(view, card_width)
	R.add_gap(view)

	R.add_section(view, "Tree-sitter Queries", card_width)
	local query_langs = #active_langs > 0 and active_langs or { lang }

	for _, query_lang in ipairs(query_langs) do
		local parts, detail = query_summary(query_lang)

		R.add_row(view, "Language", query_lang, "DebugInfo")
		R.add_row(
			view,
			"Groups",
			R.join_or_none(parts, "no query files found"),
			#parts > 0 and "DebugOk" or "DebugWarn"
		)

		for _, item in ipairs(detail) do
			for i, source in ipairs(item.sources) do
				local label = i == 1 and item.group or ""
				R.add_row(view, label, source, source:find("custom/", 1, true) and "DebugInfo" or "DebugValue")
			end
		end
	end

	R.add_footer(view, card_width)
	R.add_gap(view)

	add_tools_section(view, "Formatters", "formatter", ft, card_width)
	R.add_gap(view)
	add_tools_section(view, "Linters", "linter", ft, card_width)

	return view
end

return M
