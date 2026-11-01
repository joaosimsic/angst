-- Full-height right-column picker for the Git review hydra.
--
-- Replaces both worktree panes while choosing a branch or commit. The
-- Branch picks filter by name; commits filter by hash prefix or message.
-- The query line stays hidden until `?` is pressed and vanishes again when
-- insert mode ends. Selection applies the range; q cancels.
local M = {}

M.FILETYPE = "angst-git-picker"
M.WIDTH = 30
M.PREFIX = "Find: "
M.SEPARATOR = string.rep("─", M.WIDTH - 4)

-- Test seam: reset between specs.
local state = {
	win = nil,
	buf = nil,
	items = {},
	visible = {},
	rowmap = {},
	filter = nil,
	resolve = nil,
	on_select = nil,
	on_cancel = nil,
	query = "",
	search = false,
	search_open = false,
	submitting = false,
	title = "",
	empty_text = "(no matches)",
	updating = false,
}

local function valid_win(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
	return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local function row_offset()
	return state.search_open and 2 or 0
end

local function sync_query()
	if not state.search then
		return
	end
	if not valid_buf(state.buf) then
		return
	end
	local line = vim.api.nvim_buf_get_lines(state.buf, 0, 1, false)[1] or ""
	if line:sub(1, #M.PREFIX) == M.PREFIX then
		line = line:sub(#M.PREFIX + 1)
	end
	state.query = vim.trim(line)
end

local function render_results()
	if not valid_buf(state.buf) then
		return
	end
	local lines = {}
	state.rowmap = {}
	if state.search_open then
		local first = vim.api.nvim_buf_get_lines(state.buf, 0, 1, false)[1]
		if first == nil or first == "" then
			first = M.PREFIX .. state.query
		end
		lines[1] = first
		lines[2] = M.SEPARATOR
	end
	local start = row_offset()
	for i, item in ipairs(state.visible) do
		lines[start + i] = "  " .. item.label
		state.rowmap[start + i] = item
	end
	if #state.visible == 0 then
		lines[start + 1] = "  " .. state.empty_text
	end
	state.updating = true
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = state.search_open
	state.updating = false
end

local function apply_filter()
	local query = state.query or ""
	if state.filter ~= nil then
		local ok, filtered = pcall(state.filter, state.items, query)
		if ok and type(filtered) == "table" then
			state.visible = filtered
		else
			state.visible = {}
		end
	else
		state.visible = state.items
	end
	render_results()
end

local function close_buf()
	if valid_buf(state.buf) then
		pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
	end
end

local function select_item(item)
	if item == nil then
		return
	end
	local cb = state.on_select
	M.close()
	if cb ~= nil then
		cb(item.value)
	end
end

local function cancel()
	local cb = state.on_cancel
	M.close()
	if cb ~= nil then
		cb()
	end
end

local function focus_results(after)
	local row = row_offset() + (after or 1)
	if #state.visible == 0 then
		row = 1
	end
	pcall(vim.api.nvim_win_set_cursor, state.win, { math.max(1, row), 0 })
end

local function focus_query()
	if not state.search or not state.search_open or not valid_win(state.win) then
		return
	end
	local line = vim.api.nvim_buf_get_lines(state.buf, 0, 1, false)[1] or ""
	pcall(vim.api.nvim_win_set_cursor, state.win, { 1, #line })
	vim.cmd("startinsert")
end

local function show_search()
	if not state.search or state.search_open or not valid_buf(state.buf) then
		return
	end
	state.search_open = true
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, 1, false, { M.PREFIX .. state.query })
	render_results()
	focus_query()
end

local function hide_search()
	vim.cmd("stopinsert")
	if not state.search_open then
		return
	end
	state.search_open = false
	render_results()
	focus_results(1)
end

local function toggle_search()
	if state.search_open then
		hide_search()
	else
		show_search()
	end
end

local function submit_query()
	sync_query()
	apply_filter()
	state.submitting = true
	vim.cmd("stopinsert")
	state.submitting = false
	state.search_open = false
	render_results()
	if #state.visible == 0 then
		if state.resolve ~= nil and state.query ~= "" then
			local ok, item = pcall(state.resolve, state.query)
			if ok and type(item) == "table" then
				select_item(item)
				return
			end
		end
		vim.notify("Git review picker: no match for " .. state.query, vim.log.levels.WARN)
		return
	end
	if #state.visible == 1 then
		select_item(state.visible[1])
		return
	end
	focus_results(1)
end

local function select_under_cursor()
	local line = vim.api.nvim_win_get_cursor(state.win)[1]
	local item = state.rowmap[line]
	if item ~= nil then
		select_item(item)
		return
	end
	if state.search_open and line <= row_offset() then
		submit_query()
	end
end

local function setup_win(win)
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].winfixwidth = true
	vim.wo[win].wrap = true
	pcall(vim.api.nvim_win_set_option, win, "showbreak", "  ")
	vim.wo[win].cursorline = true
	pcall(vim.api.nvim_win_set_option, win, "winhighlight", "CursorLine:GitReviewCursor")
	pcall(vim.api.nvim_win_set_option, win, "statusline", " ")
	pcall(vim.api.nvim_win_set_option, win, "winbar", "%#GitReviewHeader# ▸ " .. state.title)
end

local function setup_maps(buf)
	vim.keymap.set("n", "<CR>", select_under_cursor, { buffer = buf, silent = true, desc = "Select target" })
	vim.keymap.set("n", "q", cancel, { buffer = buf, silent = true, desc = "Cancel picker" })
	if not state.search then
		return
	end
	vim.keymap.set("n", "?", toggle_search, { buffer = buf, silent = true, desc = "Toggle search" })
	vim.keymap.set("i", "<CR>", submit_query, { buffer = buf, silent = true, desc = "Apply search" })
	vim.keymap.set("i", "<Tab>", function()
		vim.cmd("stopinsert")
		local keys = vim.api.nvim_replace_termcodes("<Tab>", true, false, true)
		vim.api.nvim_feedkeys(keys, "m", false)
	end, { buffer = buf, silent = true, desc = "Next diff source" })
	vim.keymap.set("i", "<C-n>", function()
		vim.cmd("stopinsert")
		focus_results(1)
	end, { buffer = buf, silent = true, desc = "Move to results" })
	vim.keymap.set("i", "<Down>", function()
		vim.cmd("stopinsert")
		focus_results(1)
	end, { buffer = buf, silent = true, desc = "Move to results" })
	vim.keymap.set("i", "<C-u>", function()
		vim.api.nvim_buf_set_lines(buf, 0, 1, false, { M.PREFIX })
		state.query = ""
		apply_filter()
	end, { buffer = buf, silent = true, desc = "Clear search" })
	vim.api.nvim_create_autocmd("InsertLeave", {
		buffer = buf,
		group = vim.api.nvim_create_augroup("GitReviewPickerInsertLeave", { clear = true }),
		callback = function()
			if state.submitting or not state.search_open then
				return
			end
			if not valid_buf(state.buf) or not valid_win(state.win) then
				return
			end
			sync_query()
			state.search_open = false
			apply_filter()
			focus_results(1)
		end,
	})
	-- CTRL-C leaves Insert mode without firing InsertLeave.
	vim.keymap.set("i", "<C-c>", hide_search, { buffer = buf, silent = true, desc = "Close search" })
	vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
		buffer = buf,
		group = vim.api.nvim_create_augroup("GitReviewPickerSearch", { clear = true }),
		callback = function()
			if state.updating or not state.search_open then
				return
			end
			if vim.api.nvim_win_get_cursor(state.win)[1] ~= 1 then
				return
			end
			local before = state.query
			sync_query()
			if before ~= state.query then
				apply_filter()
			end
		end,
	})
end

---@class GitReviewPickerItem
---@field value string
---@field label string

---@param opts {title: string, items: GitReviewPickerItem[], filter?: fun(items: table[], query: string): table[], resolve?: fun(query: string): table|nil, on_select: fun(value: string), on_cancel?: fun(), empty_text?: string, initial_query?: string, width?: integer}
function M.open(opts)
	M.close()
	state.items = opts.items or {}
	state.visible = state.items
	state.filter = opts.filter
	state.resolve = opts.resolve
	state.on_select = opts.on_select
	state.on_cancel = opts.on_cancel
	state.query = opts.initial_query or ""
	state.search = opts.filter ~= nil
	state.search_open = false
	state.title = opts.title or "PICKER"
	state.empty_text = opts.empty_text or "(no matches)"
	state.rowmap = {}

	local width = opts.width or M.WIDTH
	local buf = vim.api.nvim_create_buf(false, true)
	state.buf = buf
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = M.FILETYPE
	vim.bo[buf].modifiable = true
	render_results()

	vim.cmd("botright vertical " .. width .. "split")
	state.win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(state.win, buf)
	setup_win(state.win)
	setup_maps(buf)

	pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 0 })
	return state.win
end

function M.is_open()
	return valid_win(state.win) and valid_buf(state.buf)
end

function M.close()
	if valid_win(state.win) then
		pcall(vim.api.nvim_win_close, state.win, true)
	end
	close_buf()
	state.win = nil
	state.buf = nil
	state.items = {}
	state.visible = {}
	state.rowmap = {}
	state.filter = nil
	state.resolve = nil
	state.on_select = nil
	state.on_cancel = nil
	state.query = ""
	state.search = false
	state.search_open = false
	state.submitting = false
	state.title = ""
	state.empty_text = "(no matches)"
	state.updating = false
end

---@return table[] currently visible items
function M.visible_items()
	return state.visible
end

---@param query string
function M.set_query(query)
	state.query = query or ""
	if state.search and valid_buf(state.buf) then
		if state.search_open then
			vim.api.nvim_buf_set_lines(state.buf, 0, 1, false, { M.PREFIX .. state.query })
		end
		apply_filter()
	end
end

---@return boolean
function M.is_search_open()
	return state.search_open
end

function M.cancel()
	cancel()
end

---@param value string
---@return boolean selected
function M.select(value)
	for _, item in ipairs(state.visible) do
		if item.value == value then
			select_item(item)
			return true
		end
	end
	return false
end

-- Test seam: reset module state between specs.
function M._reset()
	M.close()
end

return M
