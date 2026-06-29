local state = require("config.debug.state")

local M = {}

local TABS = { "ENGINES", "LOGS", "SETTINGS" }
local TAB_WIDTH = 12
local TAB_LEFT = ""
local TAB_RIGHT = ""

local function center_label(label, width)
	local padding = width - #label
	if padding <= 0 then
		return label
	end

	local left = math.floor(padding / 2)
	local right = padding - left
	return string.rep(" ", left) .. label .. string.rep(" ", right)
end

local function render_winbar_tabs()
	local pieces = {}

	for i, tab_name in ipairs(TABS) do
		local hl = i == state.current_tab and "DebugTabActive" or "DebugTabInactive"
		local sep_hl = hl .. "Sep"
		local label = center_label(tab_name, TAB_WIDTH)

		table.insert(
			pieces,
			string.format("%%#%s#%s%%#%s#%s%%#%s#%s", sep_hl, TAB_LEFT, hl, label, sep_hl, TAB_RIGHT)
		)
	end

	return "%#DebugTabFill# " .. table.concat(pieces, "%#DebugTabFill# ") .. "%#DebugTabFill#%="
end

local function redraw_window()
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end

	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.wo[state.win].winbar = render_winbar_tabs()
	end

	local lines = {}

	if state.current_tab == 1 then
		local engines_tab = require("config.debug.tabs.engines")
		local engine_lines = engines_tab.render(state.origin_buf)
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

	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
end

local function switch_tab(delta)
	state.current_tab = state.current_tab + delta
	if state.current_tab > #TABS then
		state.current_tab = 1
	elseif state.current_tab < 1 then
		state.current_tab = #TABS
	end

	redraw_window()
end

function M.close_debug_window()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		pcall(vim.api.nvim_win_close, state.win, true)
	end

	state.win, state.buf, state.origin_buf = nil, nil, nil
end

function M.open_debug_window()
	state.origin_buf = vim.api.nvim_get_current_buf()
	state.current_tab = 1

	local width = 65
	local height = 18
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	state.buf = vim.api.nvim_create_buf(false, true)

	state.win = vim.api.nvim_open_win(state.buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "single",
		title = " Debug Menu ",
		title_pos = "center",
	})

	vim.bo[state.buf].buftype = "nofile"
	redraw_window()

	vim.keymap.set("n", "<Tab>", function()
		switch_tab(1)
	end, { buffer = state.buf, silent = true })

	vim.keymap.set("n", "<S-Tab>", function()
		switch_tab(-1)
	end, { buffer = state.buf, silent = true })

	vim.keymap.set("n", "q", M.close_debug_window, { buffer = state.buf, silent = true })
	vim.keymap.set("n", "<Esc>", M.close_debug_window, { buffer = state.buf, silent = true })
end

return M
