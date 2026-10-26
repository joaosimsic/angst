-- Two-pane file review for the Git review hydra (replaces the quickfix list).
--
-- Right-side column, 70% files on top / 30% diffs below, each with a
-- titled winbar separator (▸ FILES (7) / ▸ DIFFS · foo.lua (2)).
-- Files show bare tail names; only the current file shows its whole
-- repo-rooted path, soft-wrapped to fit the pane (one logical line, so
-- cursor and <CR> never land mid-path). Diffs are compact kind rows:
--   ▸ domains/foo.lua           |  > 112: (+21) A
--     bar.lua                 |    11: (~5) M
--     other.lua               |    4: (+1) ??
-- One big list, no pages: `n` / `N` step files, `h` / `l` cycle diffs
-- in the current file. Each pane follows with its own window cursor
-- plus a ▸/> marker row; focus never leaves the code window, and no
-- extmark hover exists to duplicate. The diffs cursor takes the marked
-- hunk's kind color instead of the accent block. Panes open with the
-- hydra and show placeholder rows when the list is empty.
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

-- Diff row kind tints, matched on the compact "lnum(signN) kind" tail.
local KIND_MATCHES = {
	{ group = "GitReviewAdded", pattern = "\\v\\(\\+\\d+\\) A$", cursor = "GitReviewCursorAdded" },
	{ group = "GitReviewChanged", pattern = "\\v\\(\\~\\d+\\) M$", cursor = "GitReviewCursorChanged" },
	{ group = "GitReviewDeleted", pattern = "\\v\\(-\\d+\\) D$", cursor = "GitReviewCursorDeleted" },
	{ group = "GitReviewUntracked", pattern = "\\v\\(\\+\\d+\\) \\?\\?$", cursor = "GitReviewCursorUntracked" },
}

-- Cursor group for a rendered diff row's kind, or nil when the row
-- carries no kind (placeholders, legacy texts).
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
	files_win = nil,
	files_buf = nil,
	diffs_win = nil,
	diffs_buf = nil,
	files = {},
	tops = {},
	context = { file = nil, qidx = nil },
	file_rowmap = {},
	diff_rowmap = {},
	diffs_match = {},
}

local function valid_win(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
	return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

---@return boolean
function M.is_open()
	return valid_win(state.files_win)
		and valid_buf(state.files_buf)
		and valid_win(state.diffs_win)
		and valid_buf(state.diffs_buf)
end

-- Deduped absolute-path file list from the quickfix, quickfix order kept.
---@return table[] { filename = abs path, lnum = int }
function M.files_from_quickfix()
	local files, seen = {}, {}
	for _, item in ipairs(vim.fn.getqflist()) do
		local name = nil
		if item.bufnr ~= nil and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) then
			name = vim.api.nvim_buf_get_name(item.bufnr)
		elseif item.filename ~= nil and item.filename ~= "" then
			name = item.filename
		end
		if name ~= nil and name ~= "" then
			local abs = vim.fn.fnamemodify(name, ":p")
			if not seen[abs] then
				seen[abs] = true
				files[#files + 1] = { filename = abs, lnum = item.lnum and item.lnum > 0 and item.lnum or 1 }
			end
		end
	end
	return files
end

-- Deduped absolute paths in quickfix order (one per file).
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

-- True when a quickfix item belongs to buffer `bufnr` / path `abs_path`.
-- Bufnr identity first (immune to path normalization quirks),
-- `:p` string match as fallback for filename-form entries.
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

-- Quickfix entries (one per diff) for `abs_path`, in list order.
---@param abs_path string
---@return table[] { qidx = quickfix index, lnum = int|string, text = string }
local function owned_entries(abs_path)
	-- Resolve the buffer once so items match by identity, not strings.
	local bufnr = M.bufnr_for(abs_path)
	local out = {}
	for i, item in ipairs(vim.fn.getqflist()) do
		if M.same_file(item, bufnr, abs_path) then
			out[#out + 1] = {
				qidx = i,
				lnum = item.lnum and item.lnum > 0 and item.lnum or "?",
				text = item.text or "",
			}
		end
	end
	return out
end

-- File icon plus trailing space, or "" when devicons is unavailable.
-- Mirrors the heirline file component's lookup (no setup required).
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

-- Repo-toplevel-relative path for display (absolute fallback when the
-- file sits outside every known toplevel, e.g. /tmp fixtures).
---@param abs string absolute path
---@param tops? string[] toplevels to root against (defaults to the list state)
---@return string
function M.relpath(abs, tops)
	tops = tops or state.tops
	local best = nil
	for _, top in ipairs(tops) do
		if abs:sub(1, #top) == top and (abs:sub(#top + 1, #top + 1) == "/" or #abs == #top) then
			if best == nil or #top > #best then
				-- Longest match wins for nested repos.
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

-- (Re)apply the diff row kind tints, replacing the previous matches so
-- re-renders never pile them up. Window-scoped matches die with the
-- window; the stored ids only guard the re-render path.
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
	set_winbar(state.files_win, string.format("▸ %s (%d)", M.FILES_HEADER, #state.files))
	local lines = {}
	state.file_rowmap = {}
	for _, e in ipairs(state.files) do
		lines[#lines + 1] = M.file_row(e.filename, e.filename == state.context.file)
		state.file_rowmap[#lines] = e.filename
	end
	if #lines == 0 then
		lines[#lines + 1] = M.FILES_EMPTY
	end
	vim.bo[state.files_buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.files_buf, 0, -1, false, lines)
	vim.bo[state.files_buf].modifiable = false
	pcall(vim.api.nvim_win_set_width, state.files_win, M.PANE_WIDTH)
	-- Park the files cursor on the current file (row 1 fallback keeps
	-- the cursor valid on empty lists). The strong cursorline plus the
	-- ▸ marker is the hover; focus never leaves the code window.
	local parked = false
	for row, path in pairs(state.file_rowmap) do
		if path == state.context.file then
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
		local current = d.qidx == state.context.qidx
		if current then
			marked = #lines + 1
		end
		lines[#lines + 1] = (current and "> " or "  ") .. d.text
		state.diff_rowmap[#lines] = d.qidx
	end
	if #lines == 0 then
		lines[#lines + 1] = M.DIFFS_EMPTY
	end
	vim.bo[state.diffs_buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.diffs_buf, 0, -1, false, lines)
	vim.bo[state.diffs_buf].modifiable = false
	pcall(vim.api.nvim_win_set_width, state.diffs_win, M.PANE_WIDTH)
	mark_kinds(state.diffs_win)
	-- Park the diffs cursor on the current diff (or the first row) and
	-- paint the selection with that hunk's kind color.
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

-- Rebuild everything for `file_abs` with the `qidx` diff marked.
-- Pass nil qidx for no marker.
---@param file_abs? string
---@param qidx? integer
function M.render_all(file_abs, qidx)
	state.files = M.files_from_quickfix()
	state.tops = review_files.repo_toplevels()
	state.context = { file = file_abs, qidx = qidx }
	M.render()
end

function M.refresh()
	state.files = M.files_from_quickfix()
	state.tops = review_files.repo_toplevels()
	M.render()
end

local function jump_to_entry(entry)
	if entry == nil then
		return false
	end
	-- Never run `cc` from inside a pane: it would land the cursor there.
	local cur = vim.api.nvim_get_current_win()
	if cur == state.files_win or cur == state.diffs_win then
		pcall(vim.cmd, "wincmd p")
	end
	-- Prefer the quickfix index so we land on the hunk line.
	local idx = nil
	for i, item in ipairs(vim.fn.getqflist()) do
		local name = nil
		if item.bufnr ~= nil and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) then
			name = vim.api.nvim_buf_get_name(item.bufnr)
		elseif item.filename ~= nil and item.filename ~= "" then
			name = item.filename
		end
		if name ~= nil and vim.fn.fnamemodify(name, ":p") == entry.filename then
			idx = i
			break
		end
	end
	if idx ~= nil then
		pcall(vim.cmd, "cc " .. idx)
	else
		pcall(vim.cmd, "edit " .. vim.fn.fnameescape(entry.filename))
		pcall(vim.api.nvim_win_set_cursor, 0, { entry.lnum, 0 })
	end
	pcall(vim.cmd, "normal! zz")
	return true
end

local function jump_from_pane_cursor(win, rowmap, kind)
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
	if kind == "diff" then
		pcall(vim.cmd, "cc " .. target)
	elseif target ~= nil then
		jump_to_entry({ filename = target, lnum = 1 })
	end
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
	-- Long selected paths soft-wrap to fit (one logical line, so the
	-- cursor and <CR> never land mid-path); continuation lines get a
	-- two-space showbreak instead of looking like new rows.
	vim.wo[win].wrap = true
	pcall(vim.api.nvim_win_set_option, win, "showbreak", "  ")
	-- The hover is this window's own cursorline, painted strong so the
	-- parked row is unmissable. Never inherit the code window's
	-- cursorline: that painted a second, duplicated hover.
	-- No extmarks anywhere (their end_row is inclusive and bled below).
	vim.wo[win].cursorline = true
	pcall(vim.api.nvim_win_set_option, win, "winhighlight", "CursorLine:GitReviewCursor")
	-- Blank window-local statusline: keeps heirline out of the narrow
	-- panes. Titles live in the winbars, set per render.
	pcall(vim.api.nvim_win_set_option, win, "statusline", " ")
end

function M.open()
	if M.is_open() then
		M.refresh()
		return state.files_win
	end
	-- The bottom quickfix window must never share the screen with the
	-- list: close it (list data is preserved, only the window closes).
	pcall(vim.cmd, "cclose")
	-- Drop stray halves (e.g. the user closed one pane by hand).
	M.close()
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
	local total = vim.api.nvim_win_get_height(state.files_win)
		+ vim.api.nvim_win_get_height(state.diffs_win)
		+ 1
	pcall(
		vim.api.nvim_win_set_height,
		state.files_win,
		math.max(1, math.floor(total * M.FILES_SHARE))
	)
	-- Back to the code window: `j`/`k` stay normal motion there.
	if valid_win(code_win) then
		pcall(vim.api.nvim_set_current_win, code_win)
	else
		pcall(vim.cmd, "wincmd p")
		pcall(vim.cmd, "wincmd p")
	end
	M.render_all(
		vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p"),
		vim.fn.getqflist({ idx = 0 }).idx
	)
	return state.files_win
end

function M.close()
	for _, win in ipairs({ state.files_win, state.diffs_win }) do
		if valid_win(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end
	state.files_win = nil
	state.diffs_win = nil
	-- Buffers wipe themselves (`bufhidden=wipe`); drop stale handles.
	if not valid_buf(state.files_buf) then
		state.files_buf = nil
	end
	if not valid_buf(state.diffs_buf) then
		state.diffs_buf = nil
	end
end

-- Test seam: reset module state between specs.
function M._reset()
	M.close()
	state.files = {}
	state.tops = {}
	state.context = { file = nil, qidx = nil }
	state.file_rowmap = {}
	state.diff_rowmap = {}
	state.diffs_match = {}
end

return M
