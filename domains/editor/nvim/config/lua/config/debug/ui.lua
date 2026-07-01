local state = require("config.debug.state")

local M = {}

local TABS = { "ENGINES", "LOGS", "ENVIRONMENT", "KEYMAPS" }
local TAB_WIDTH = 13
local TAB_LEFT = ""
local TAB_RIGHT = ""
local DEBUG_NS = vim.api.nvim_create_namespace("debug.window")
local LOG_AUGROUP = vim.api.nvim_create_augroup("DebugWindowLogs", { clear = true })

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

		table.insert(pieces, string.format("%%#%s#%s%%#%s#%s%%#%s#%s", sep_hl, TAB_LEFT, hl, label, sep_hl, TAB_RIGHT))
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

	---@type { lines: string[], highlights: table[] }
	local rendered = {
		lines = {},
		highlights = {},
	}

	local content_width = state.win
		and vim.api.nvim_win_is_valid(state.win)
		and vim.api.nvim_win_get_width(state.win) - 2
		or 84

	if state.current_tab == 1 then
		local engines_tab = require("config.debug.tabs.engines")
		rendered = engines_tab.render(state.origin_buf, content_width)
	elseif state.current_tab == 2 then
		local logs_tab = require("config.debug.tabs.logs")
		rendered = logs_tab.render(content_width)
	elseif state.current_tab == 3 then
		local environment_tab = require("config.debug.tabs.environment")
		rendered = environment_tab.render(state.origin_buf, content_width)
	elseif state.current_tab == 4 then
		local keymaps_tab = require("config.debug.tabs.keymaps")
		rendered = keymaps_tab.render(state.origin_buf, content_width)
	end

	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, rendered.lines)
	vim.bo[state.buf].modifiable = false

	vim.api.nvim_buf_clear_namespace(state.buf, DEBUG_NS, 0, -1)
	for _, highlight in ipairs(rendered.highlights or {}) do
		local line = rendered.lines[highlight.line] or ""
		local start_col = highlight.start_col or 0
		local end_col = highlight.end_col or #line

		if end_col < 0 then
			end_col = #line
		end

		pcall(vim.api.nvim_buf_set_extmark, state.buf, DEBUG_NS, highlight.line - 1, start_col, {
			end_col = end_col,
			hl_group = highlight.group,
		})
	end
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

	local width = math.min(math.floor(vim.o.columns * 0.8), math.max(84, vim.o.columns - 8))
	local height = math.min(math.floor(vim.o.lines * 0.7), math.max(20, vim.o.lines - 4))
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
	vim.bo[state.buf].bufhidden = "wipe"
	vim.bo[state.buf].modifiable = false
	vim.bo[state.buf].filetype = "debug"
	vim.wo[state.win].cursorline = true
	vim.wo[state.win].wrap = false
	redraw_window()

	vim.keymap.set("n", "<Tab>", function()
		switch_tab(1)
	end, { buffer = state.buf, silent = true })

	vim.keymap.set("n", "<S-Tab>", function()
		switch_tab(-1)
	end, { buffer = state.buf, silent = true })

	vim.keymap.set("n", "q", M.close_debug_window, { buffer = state.buf, silent = true })
	vim.keymap.set("n", "<Esc>", M.close_debug_window, { buffer = state.buf, silent = true })

	vim.api.nvim_clear_autocmds({ group = LOG_AUGROUP })
	vim.api.nvim_create_autocmd("User", {
		group = LOG_AUGROUP,
		pattern = "DebugLogAdded",
		callback = function()
			if state.buf and vim.api.nvim_buf_is_valid(state.buf) and state.current_tab == 2 then
				redraw_window()
			end
		end,
	})
end

return M
