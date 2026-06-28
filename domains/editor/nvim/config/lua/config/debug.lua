local Hydra = require("common.Hydra")
local AdapterScanner = require("backend.shared.AdapterScanner")

local M = {}

-- State variables to track the active UI instances
local state = {
	win = nil,
	buf = nil,
	current_tab = 1,
	origin_buf = nil, -- Track where the user opened the window from
}

-- Define your available tabs
local TABS = { "Engine Status", "Logs", "Settings" }

local function get_engine_status(bufnr)
	local ft = vim.bo[bufnr].filetype
	if ft == "" then
		ft = "none"
	end

	local lines = {
		string.format(" Buffer: %d | Filetype: %s", bufnr, ft),
		"------------------------------",
		"",
	}

	table.insert(lines, "● LSP:")
	local lsp_clients = vim.lsp.get_clients({ bufnr = bufnr })
	if #lsp_clients == 0 then
		table.insert(lines, "  State: 🛑 No active clients attached.")
	else
		for _, client in ipairs(lsp_clients) do
			table.insert(lines, string.format("  State: 🟢 Active [%s] (ID: %d)", client.name, client.id))
		end
	end
	table.insert(lines, "")

	table.insert(lines, "● Tree-sitter:")
	local has_highlighter = vim.treesitter.highlighter.active[bufnr] ~= nil
	if has_highlighter then
		local lang = vim.treesitter.language.get_lang(ft) or ft
		table.insert(lines, string.format("  State: 🟢 Active (Parser: %s)", lang))
	else
		table.insert(lines, "  State: 🛑 Inactive / No parser attached.")
	end
	table.insert(lines, "")

	table.insert(lines, "● Formatter:")
	local formatters = AdapterScanner:tools_for_filetype("formatter", ft, { check_executable = true })
	if #formatters == 0 then
		table.insert(lines, "  State: 🛑 None configured.")
	else
		table.insert(lines, "  Configured: " .. table.concat(formatters, ", "))
	end
	table.insert(lines, "")

	table.insert(lines, "● Linter:")
	local linters = AdapterScanner:tools_for_filetype("linter", ft, { check_executable = true })
	if #linters == 0 then
		table.insert(lines, "  State: 🛑 None configured.")
	else
		table.insert(lines, "  Configured: " .. table.concat(linters, ", "))
	end

	return lines
end

-- Renders the top tab headers dynamically based on state.current_tab
local function render_tabs_header()
	local headers = {}
	for i, tab_name in ipairs(TABS) do
		if i == state.current_tab then
			table.insert(headers, string.format("▶ [%s] ◀", tab_name))
		else
			table.insert(headers, string.format("  %s  ", tab_name))
		end
	end
	return " " .. table.concat(headers, " | ")
end

-- Main view router
local function redraw_window()
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end

	local lines = {
		render_tabs_header(),
		"============================================================",
		"",
	}

	-- Direct content loading depending on selected tab
	if state.current_tab == 1 then
		local engine_lines = get_engine_status(state.origin_buf)
		for _, line in ipairs(engine_lines) do
			table.insert(lines, line)
		end
	elseif state.current_tab == 2 then
		table.insert(lines, "  🪵  Backend Logs go here...")
		table.insert(lines, "  (Feature coming soon)")
	elseif state.current_tab == 3 then
		table.insert(lines, "  ⚙️  Engine Settings go here...")
		table.insert(lines, "  (Feature coming soon)")
	end

	-- Update buffer safely despite modifiable = false
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
end

-- Navigation controls
local function switch_tab(delta)
	state.current_tab = state.current_tab + delta
	if state.current_tab > #TABS then
		state.current_tab = 1
	elseif state.current_tab < 1 then
		state.current_tab = #TABS
	end
	redraw_window()
end

function M.open_debug_window()
	-- Store active context buffer before opening UI
	state.origin_buf = vim.api.nvim_get_current_buf()
	state.current_tab = 1

	local width = 65
	local height = 18
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	state.buf = vim.api.nvim_create_buf(false, true)

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "single",
		title = " Backend Debug Mode ",
		title_pos = "center",
	}

	state.win = vim.api.nvim_open_win(state.buf, true, opts)

	vim.bo[state.buf].buftype = "nofile"
	redraw_window()

	-- Tab controls mappings
	vim.keymap.set("n", "<Tab>", function()
		switch_tab(1)
	end, { buffer = state.buf, silent = true })
	vim.keymap.set("n", "<S-Tab>", function()
		switch_tab(-1)
	end, { buffer = state.buf, silent = true })

	-- Close handlers
	local function close_ui()
		if state.win and vim.api.nvim_win_is_valid(state.win) then
			pcall(vim.api.nvim_win_close, state.win, true)
		end
		state.win, state.buf, state.origin_buf = nil, nil, nil
	end

	vim.keymap.set("n", "q", close_ui, { buffer = state.buf, silent = true })
	vim.keymap.set("n", "<Esc>", close_ui, { buffer = state.buf, silent = true })
end

M.hydra = Hydra.new({
	name = "Debug",
	fg_color = "yellow_bright",
	bg_color = "black",
	enter = "<leader>v",
	heads = {
		{ "s", M.open_debug_window, "Show Backend Engine Status" },
	},
})

return M
