-- Worktree/range file review for the Git review hydra (replaces quickfix).
--
-- Right-side column, 70% files on top / 30% diffs below, each with a
-- titled winbar separator. The same panes serve the worktree quickfix
-- and a selected branch/commit range; only the entry source changes.
-- `n` / `N` step files, `h` / `l` cycle diffs, and focus never leaves
-- the code window. Panes show placeholders when the source is empty.
local M = {}

local review_files = require("frontend.tools.git_review_files")

M.PANE_WIDTH = 30
M.FILES_SHARE = 0.7
M.FILES_FILETYPE = "angst-git-files"
M.DIFFS_FILETYPE = "angst-git-diffs"

M.FILES_HEADER = "FILES"
M.DIFFS_HEADER = "DIFFS"
M.FILES_EMPTY = "(no changed files)"
M.DIFFS_EMPTY = "(no diffs)"
M.FILES_LOADING = "(collecting changed files…)"
M.DIFFS_LOADING = "(waiting for changed files…)"

local SIDEBAR_FILETYPES = {
	M.FILES_FILETYPE,
	M.DIFFS_FILETYPE,
	"angst-git-branch-files",
	"angst-git-branch-diffs",
	"angst-git-commit-files",
	"angst-git-commit-diffs",
}

local KIND_MATCHES = {
	{ group = "GitReviewAdded", pattern = "\\v\\(\\+\\d+\\) A$", cursor = "GitReviewCursorAdded" },
	{ group = "GitReviewChanged", pattern = "\\v\\(\\~\\d+\\) M$", cursor = "GitReviewCursorChanged" },
	{ group = "GitReviewDeleted", pattern = "\\v\\(-\\d+\\) D$", cursor = "GitReviewCursorDeleted" },
	{ group = "GitReviewUntracked", pattern = "\\v\\(\\+\\d+\\) \\?\\?$", cursor = "GitReviewCursorUntracked" },
}

---@param row? string
---@return string?
local function cursor_kind_for(row)
	if type(row) ~= "string" then
		return nil
	end
	for _, m in ipairs(KIND_MATCHES) do
		if vim.fn.match(row, m.pattern) >= 0 then
			return m.cursor
		end
	end
	return nil
end

local state = {
	source = "worktree",
	range_entries = {},
	range_tops = {},
	range_label = nil,
	files_win = nil,
	files_buf = nil,
	diffs_win = nil,
	diffs_buf = nil,
	files = {},
	tops = {},
	context = { file = nil, index = nil },
	file_rowmap = {},
	diff_rowmap = {},
	diffs_match = {},
	loading = false,
}

local function valid_win(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
	return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

---@param entry table
---@return string? absolute path
local function entry_abs(entry)
	local name = nil
	if entry.bufnr ~= nil and entry.bufnr > 0 and vim.api.nvim_buf_is_valid(entry.bufnr) then
		name = vim.api.nvim_buf_get_name(entry.bufnr)
	elseif entry.filename ~= nil and entry.filename ~= "" then
		name = entry.filename
	end
	if name == nil or name == "" then
		return nil
	end
	return vim.fn.fnamemodify(name, ":p")
end

local function source_entries()
	if state.source == "range" then
		return state.range_entries
	end
	return vim.fn.getqflist()
end

---@return boolean
function M.is_open()
	return valid_win(state.files_win)
		and valid_buf(state.files_buf)
		and valid_win(state.diffs_win)
		and valid_buf(state.diffs_buf)
end

-- Close every sidebar window, including stale branch/commit panes from
-- older sessions or hot reloads. Tracked handles are not enough: a lost
-- handle would otherwise leave a duplicate column behind.
function M.close_sidebars()
	local wins = vim.api.nvim_list_wins()
	for _, win in ipairs(wins) do
		if valid_win(win) then
			local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
			for _, sidebar_ft in ipairs(SIDEBAR_FILETYPES) do
				if ft == sidebar_ft then
					pcall(vim.api.nvim_win_close, win, true)
					break
				end
			end
		end
	end
	state.files_win = nil
	state.diffs_win = nil
	if not valid_buf(state.files_buf) then
		state.files_buf = nil
	end
	if not valid_buf(state.diffs_buf) then
		state.diffs_buf = nil
	end
end

-- Deduped absolute-path file list from the current source.
---@return table[] { filename = abs path, lnum = int, index = entry index }
function M.files_from_quickfix()
	local files, seen = {}, {}
	for i, item in ipairs(source_entries()) do
		local abs = entry_abs(item)
		if abs ~= nil and not seen[abs] then
			seen[abs] = true
			files[#files + 1] = {
				filename = abs,
				lnum = item.lnum and item.lnum > 0 and item.lnum or 1,
				index = i,
			}
		end
	end
	return files
end

-- Deduped absolute paths in source order (one per file).
---@return string[]
function M.ordered_files()
	local out = {}
	for _, e in ipairs(M.files_from_quickfix()) do
		out[#out + 1] = e.filename
	end
	return out
end

-- Buffer holding `abs_path`, or nil when the file isn't open.
---@param abs_path string
---@return integer|nil
function M.bufnr_for(abs_path)
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(b) then
			local ok, name = pcall(vim.api.nvim_buf_get_name, b)
			if ok and name ~= "" and vim.fn.fnamemodify(name, ":p") == abs_path then
				return b
			end
		end
	end
	return nil
end

-- True when a source entry belongs to buffer `bufnr` / path `abs_path`.
---@param item table
---@param bufnr? integer
---@param abs_path string
function M.same_file(item, bufnr, abs_path)
	if bufnr ~= nil and bufnr > 0 and item.bufnr ~= nil and item.bufnr > 0 then
		return item.bufnr == bufnr
	end
	local name = nil
	if item.bufnr ~= nil and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) then
		name = vim.api.nvim_buf_get_name(item.bufnr)
	elseif item.filename ~= nil and item.filename ~= "" then
		name = item.filename
	end
	return name ~= nil and vim.fn.fnamemodify(name, ":p") == abs_path
end

-- Source entries (one per diff) for `abs_path`, in source order.
---@param abs_path string
---@return table[] { index = entry index, lnum = int|string, text = string }
local function owned_entries(abs_path)
	local bufnr = M.bufnr_for(abs_path)
	local out = {}
	for i, item in ipairs(source_entries()) do
		if M.same_file(item, bufnr, abs_path) then
			out[#out + 1] = {
				index = i,
				lnum = item.lnum and item.lnum > 0 and item.lnum or "?",
				text = item.text or "",
			}
		end
	end
	return out
end

-- File icon plus trailing space, or "" when devicons is unavailable.
---@param abs string absolute path
---@return string
function M.icon_for(abs)
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if not ok or type(devicons) ~= "table" or type(devicons.get_icon) ~= "function" then
		return ""
	end
	local name = vim.fn.fnamemodify(abs, ":t")
	local ext = vim.fn.fnamemodify(abs, ":e")
	local ok_icon, icon = pcall(devicons.get_icon, name, ext, { default = false })
	if not ok_icon or type(icon) ~= "string" or icon == "" then
		return ""
	end
	return icon .. " "
end

-- Repo-toplevel-relative path for display.
---@param abs string absolute path
---@param tops? string[]
---@return string
function M.relpath(abs, tops)
	tops = tops or state.tops
	local best = nil
	for _, top in ipairs(tops) do
		if abs:sub(1, #top) == top and (abs:sub(#top + 1, #top + 1) == "/" or #abs == #top) then
			if best == nil or #top > #best then
				best = top
			end
		end
	end
	if best == nil then
		return abs
	end
	local rel = abs:sub(#best + 2)
	return rel == "" and abs or rel
end

---@param win integer
---@param text string
local function set_winbar(win, text)
	if valid_win(win) then
		pcall(vim.api.nvim_win_set_option, win, "winbar", "%#GitReviewHeader# " .. text .. "%*")
	end
end

local function set_pane_lines(buf, lines)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
end

-- One file row: bare tail name, except the current file which shows
-- its whole repo-rooted path on a single (soft-wrapped) line.
---@param abs string absolute path
---@param is_current boolean
---@param tops? string[]
---@return string display line
function M.file_row(abs, is_current, tops)
	local icon = M.icon_for(abs)
	if not is_current then
		return "  " .. icon .. vim.fn.fnamemodify(M.relpath(abs, tops), ":t")
	end
	return "▸ " .. icon .. M.relpath(abs, tops)
end

-- (Re)apply the diff row kind tints, replacing the previous matches.
---@param win integer
local function mark_kinds(win)
	if state.diffs_match ~= nil then
		for _, id in ipairs(state.diffs_match) do
			pcall(vim.fn.matchdelete, id, win)
		end
	end
	state.diffs_match = {}
	if valid_win(win) then
		for _, m in ipairs(KIND_MATCHES) do
			local ok, id = pcall(vim.fn.matchadd, m.group, m.pattern, 10, -1, { window = win })
			if ok and id ~= nil then
				state.diffs_match[#state.diffs_match + 1] = id
			end
		end
	end
end

function M.render_files()
	if not valid_win(state.files_win) or not valid_buf(state.files_buf) then
		return
	end
	if state.loading then
		set_winbar(state.files_win, string.format("▸ %s (loading…)", M.FILES_HEADER))
		state.file_rowmap = {}
		set_pane_lines(state.files_buf, { M.FILES_LOADING })
		pcall(vim.api.nvim_win_set_width, state.files_win, M.PANE_WIDTH)
		pcall(vim.api.nvim_win_set_cursor, state.files_win, { 1, 0 })
		return
	end
	set_winbar(state.files_win, string.format("▸ %s (%d)", M.FILES_HEADER, #state.files))
	local lines = {}
	state.file_rowmap = {}
	for _, e in ipairs(state.files) do
		lines[#lines + 1] = M.file_row(e.filename, e.filename == state.context.file)
		state.file_rowmap[#lines] = e
	end
	if #lines == 0 then
		lines[#lines + 1] = M.FILES_EMPTY
	end
	set_pane_lines(state.files_buf, lines)
	pcall(vim.api.nvim_win_set_width, state.files_win, M.PANE_WIDTH)
	local parked = false
	for row, e in pairs(state.file_rowmap) do
		if e.filename == state.context.file then
			parked = pcall(vim.api.nvim_win_set_cursor, state.files_win, { row, 0 })
			break
		end
	end
	if not parked then
		pcall(vim.api.nvim_win_set_cursor, state.files_win, { 1, 0 })
	end
end

function M.render_diffs()
	if not valid_win(state.diffs_win) or not valid_buf(state.diffs_buf) then
		return
	end
	if state.loading then
		set_winbar(state.diffs_win, string.format("▸ %s (loading…)", M.DIFFS_HEADER))
		state.diff_rowmap = {}
		set_pane_lines(state.diffs_buf, { M.DIFFS_LOADING })
		pcall(vim.api.nvim_win_set_width, state.diffs_win, M.PANE_WIDTH)
		pcall(vim.api.nvim_win_set_cursor, state.diffs_win, { 1, 0 })
		return
	end
	local file = state.context.file
	local diffs = {}
	if file ~= nil and file ~= "" then
		diffs = owned_entries(file)
	end
	if file ~= nil and file ~= "" then
		set_winbar(
			state.diffs_win,
			string.format("▸ %s · %s (%d)", M.DIFFS_HEADER, vim.fn.fnamemodify(file, ":t"), #diffs)
		)
	else
		set_winbar(state.diffs_win, string.format("▸ %s", M.DIFFS_HEADER))
	end
	local lines = {}
	state.diff_rowmap = {}
	local marked = nil
	for _, d in ipairs(diffs) do
		local current = d.index == state.context.index
		if current then
			marked = #lines + 1
		end
		lines[#lines + 1] = (current and "> " or "  ") .. d.text
		state.diff_rowmap[#lines] = d
	end
	if #lines == 0 then
		lines[#lines + 1] = M.DIFFS_EMPTY
	end
	vim.bo[state.diffs_buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.diffs_buf, 0, -1, false, lines)
	vim.bo[state.diffs_buf].modifiable = false
	pcall(vim.api.nvim_win_set_width, state.diffs_win, M.PANE_WIDTH)
	mark_kinds(state.diffs_win)
	local cursor_group = "GitReviewCursor"
	if marked ~= nil then
		local kind = cursor_kind_for(lines[marked])
		if kind ~= nil then
			cursor_group = kind
		end
	end
	pcall(vim.api.nvim_win_set_option, state.diffs_win, "winhighlight", "CursorLine:" .. cursor_group)
	pcall(vim.api.nvim_win_set_cursor, state.diffs_win, { marked or 1, 0 })
end

function M.render()
	M.render_files()
	M.render_diffs()
end

-- Rebuild everything for `file_abs` with the `index` entry marked.
---@param file_abs? string
---@param index? integer
function M.render_all(file_abs, index)
	state.files = M.files_from_quickfix()
	state.tops = state.source == "range" and state.range_tops or review_files.repo_toplevels()
	state.context = { file = file_abs, index = index }
	M.render()
end

function M.refresh()
	if state.loading then
		M.render()
		return
	end
	state.files = M.files_from_quickfix()
	state.tops = state.source == "range" and state.range_tops or review_files.repo_toplevels()
	M.render()
end

---@return boolean
function M.is_worktree()
	return state.source == "worktree"
end

-- Show a loading placeholder while the worktree source is collected.
-- Turning loading off only clears the flag; the caller then refreshes
-- with the freshly written quickfix list.
---@param loading boolean
function M.set_loading(loading)
	state.loading = loading and true or false
	if state.loading then
		state.files = {}
		state.tops = {}
		state.context = { file = nil, index = nil }
		state.file_rowmap = {}
		state.diff_rowmap = {}
		if M.is_open() then
			M.render()
		end
	end
end

-- Switch the panes to a branch/commit range entry list.
---@param entries table[]
---@param tops? string[]
---@param label? string
function M.show_range(entries, tops, label)
	state.source = "range"
	state.loading = false
	state.range_entries = entries or {}
	state.range_tops = tops or {}
	state.range_label = label
	state.context = { file = nil, index = nil }
	if M.is_open() then
		M.refresh()
	end
end

-- Switch the panes back to the worktree quickfix.
function M.show_worktree()
	state.source = "worktree"
	state.loading = false
	state.range_entries = {}
	state.range_tops = {}
	state.range_label = nil
	state.context = { file = nil, index = nil }
	if M.is_open() then
		M.refresh()
	end
end

---@param index integer
---@return boolean
local function jump_to_index(index)
	if state.source ~= "range" then
		local ok = pcall(vim.cmd, "cc " .. index)
		return ok
	end
	local entry = state.range_entries[index]
	if entry == nil then
		return false
	end
	local abs = entry_abs(entry)
	if abs == nil then
		return false
	end
	local cur_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()), ":p")
	if cur_name ~= abs then
		local ok = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(abs))
		if not ok then
			return false
		end
	end
	local lnum = entry.lnum and entry.lnum > 0 and entry.lnum or 1
	pcall(vim.api.nvim_win_set_cursor, 0, { lnum, 0 })
	pcall(vim.cmd, "normal! zz")
	return true
end

local function jump_from_pane_cursor(win, rowmap, _kind)
	if not M.is_open() then
		return
	end
	if vim.api.nvim_get_current_win() == win then
		pcall(vim.cmd, "wincmd p")
	end
	local cursor = vim.api.nvim_win_get_cursor(win)
	local target = rowmap[cursor[1]]
	if target == nil then
		return
	end
	jump_to_index(target.index)
	pcall(vim.cmd, "normal! zz")
end

local function jump_from_files_cursor()
	jump_from_pane_cursor(state.files_win, state.file_rowmap, "file")
end

local function jump_from_diffs_cursor()
	jump_from_pane_cursor(state.diffs_win, state.diff_rowmap, "diff")
end

---@param buf integer
---@param filetype string
---@param on_cr fun()
---@param label string
local function setup_pane_buf(buf, filetype, on_cr, label)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = filetype
	vim.keymap.set("n", "<CR>", on_cr, { buffer = buf, silent = true, desc = label })
	vim.keymap.set("n", "q", function()
		M.close()
	end, { buffer = buf, silent = true, desc = "Close panes" })
end

---@param win integer
local function setup_pane_win(win)
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].winfixwidth = true
	vim.wo[win].wrap = true
	pcall(vim.api.nvim_win_set_option, win, "showbreak", "  ")
	vim.wo[win].cursorline = true
	pcall(vim.api.nvim_win_set_option, win, "winhighlight", "CursorLine:GitReviewCursor")
	pcall(vim.api.nvim_win_set_option, win, "statusline", " ")
end

function M.open()
	if M.is_open() then
		M.refresh()
		return state.files_win
	end
	-- Stale sidebars (lost handles, old range panes) must never survive.
	pcall(vim.cmd, "cclose")
	M.close_sidebars()
	local code_win = vim.api.nvim_get_current_win()
	local files_buf = vim.api.nvim_create_buf(false, true)
	setup_pane_buf(files_buf, M.FILES_FILETYPE, jump_from_files_cursor, "Jump to file")
	vim.cmd("botright vertical " .. M.PANE_WIDTH .. "split")
	state.files_win = vim.api.nvim_get_current_win()
	state.files_buf = files_buf
	vim.api.nvim_win_set_buf(state.files_win, files_buf)
	setup_pane_win(state.files_win)
	local diffs_buf = vim.api.nvim_create_buf(false, true)
	setup_pane_buf(diffs_buf, M.DIFFS_FILETYPE, jump_from_diffs_cursor, "Jump to diff")
	vim.cmd("belowright split")
	state.diffs_win = vim.api.nvim_get_current_win()
	state.diffs_buf = diffs_buf
	vim.api.nvim_win_set_buf(state.diffs_win, diffs_buf)
	setup_pane_win(state.diffs_win)
	-- 70% files on top, diffs take the rest of the column.
	local total = vim.api.nvim_win_get_height(state.files_win) + vim.api.nvim_win_get_height(state.diffs_win) + 1
	pcall(vim.api.nvim_win_set_height, state.files_win, math.max(1, math.floor(total * M.FILES_SHARE)))
	-- Back to the code window: `j`/`k` stay normal motion there.
	if valid_win(code_win) then
		pcall(vim.api.nvim_set_current_win, code_win)
	else
		pcall(vim.cmd, "wincmd p")
		pcall(vim.cmd, "wincmd p")
	end
	if state.loading then
		M.render()
	else
		local index = state.source == "range" and state.context.index or vim.fn.getqflist({ idx = 0 }).idx
		M.render_all(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p"), index)
	end
	return state.files_win
end

function M.close()
	M.close_sidebars()
end

-- Test seam: reset module state between specs.
function M._reset()
	M.close()
	state.source = "worktree"
	state.range_entries = {}
	state.range_tops = {}
	state.range_label = nil
	state.files = {}
	state.tops = {}
	state.context = { file = nil, index = nil }
	state.file_rowmap = {}
	state.diff_rowmap = {}
	state.diffs_match = {}
	state.loading = false
end

return M
