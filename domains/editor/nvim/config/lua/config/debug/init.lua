local Hydra = require("common.Hydra")
local state = require("config.debug.state")

local M = {}

local TABS = { "ENGINES", "LOGS", "SETTINGS" }

local function render_winbar_tabs()
	local pieces = {}
	for i, tab_name in ipairs(TABS) do
		if i == state.current_tab then
			table.insert(pieces, string.format("%%#TabLineSel#  %s  %%*", tab_name))
		else
			table.insert(pieces, string.format("%%#TabLine#  %s  %%*", tab_name))
		end
	end
	return " " .. table.concat(pieces, " ")
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

function M.open_debug_window()
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

	vim.keymap.set("n", "<Tab>", function()
		switch_tab(1)
	end, { buffer = state.buf, silent = true })
	vim.keymap.set("n", "<S-Tab>", function()
		switch_tab(-1)
	end, { buffer = state.buf, silent = true })

	local function close_ui()
		if state.win and vim.api.nvim_win_is_valid(state.win) then
			pcall(vim.api.nvim_win_close, state.win, true)
		end
		state.win, state.buf, state.origin_buf = nil, nil, nil
	end

	vim.keymap.set("n", "q", close_ui, { buffer = state.buf, silent = true })
	vim.keymap.set("n", "<Esc>", close_ui, { buffer = state.buf, silent = true })
end

---@type Plugin
return {
	"debug",
	virtual = true,
	lazy = false,
	config = function(bufnr)
		M.hydra = Hydra.new({
			name = "Debug",
			fg_color = "yellow_bright",
			bg_color = "black",
			enter = "<leader>v",
			heads = {
				{ "s", M.open_debug_window, "Show Backend Engine Status" },
			},
		}, bufnr)
	end,
}
