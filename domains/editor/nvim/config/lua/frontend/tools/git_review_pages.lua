-- Two-pane file review for the Git review hydra (replaces the quickfix list).
--
-- Right-side column, 70% files on top / 30% diffs below:
--   Changed files (7)          |  Diffs in foo.lua (2)
--   foo.lua                    |  > 12: removed line
--   bar.lua                    |    30: added line
-- One big list, no pages: `n` / `N` step files, `h` / `l` cycle diffs
-- in the current file. Each pane follows with its own window cursor
-- (cursorline); focus never leaves the code window, and no extmark
-- hover exists to duplicate.
local M = {}

M.PANE_WIDTH = 30
M.FILES_SHARE = 0.7
M.FILES_FILETYPE = "angst-git-files"
M.DIFFS_FILETYPE = "angst-git-diffs"

local state = {
	files_win = nil,
	files_buf = nil,
	diffs_win = nil,
	diffs_buf = nil,
	files = {},
	context = { file = nil, qidx = nil },
	file_rowmap = {},
	diff_rowmap = {},
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

function M.render_files()
	if not valid_win(state.files_win) or not valid_buf(state.files_buf) then
		return
	end
	local lines = {
		string.format("Changed files (%d)", #state.files),
	}
	state.file_rowmap = {}
	for _, e in ipairs(state.files) do
		-- Filenames only, no paths.
		lines[#lines + 1] = vim.fn.fnamemodify(e.filename, ":t")
		state.file_rowmap[#lines] = e.filename
	end
	vim.bo[state.files_buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.files_buf, 0, -1, false, lines)
	vim.bo[state.files_buf].modifiable = false
	pcall(vim.api.nvim_win_set_width, state.files_win, M.PANE_WIDTH)
	-- Park the files cursor on the current file. The window cursorline
	-- is the only hover; focus never leaves the code window.
	for row, path in pairs(state.file_rowmap) do
		if path == state.context.file then
			pcall(vim.api.nvim_win_set_cursor, state.files_win, { row, 0 })
			break
		end
	end
end

function M.render_diffs()
	if not valid_win(state.diffs_win) or not valid_buf(state.diffs_buf) then
		return
	end
	local file = state.context.file
	local lines = {}
	local diffs = {}
	if file ~= nil and file ~= "" then
		diffs = owned_entries(file)
		lines[#lines + 1] = string.format(
			"Diffs in %s (%d)",
			vim.fn.fnamemodify(file, ":t"),
			#diffs
		)
	else
		lines[#lines + 1] = "Diffs in - (0)"
	end
	state.diff_rowmap = {}
	local marked = nil
	for _, d in ipairs(diffs) do
		local current = d.qidx == state.context.qidx
		if current then
			marked = #lines + 1
		end
		lines[#lines + 1] = string.format("%s%s: %s", current and "> " or "  ", d.lnum, d.text)
		state.diff_rowmap[#lines] = d.qidx
	end
	vim.bo[state.diffs_buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.diffs_buf, 0, -1, false, lines)
	vim.bo[state.diffs_buf].modifiable = false
	pcall(vim.api.nvim_win_set_width, state.diffs_win, M.PANE_WIDTH)
	-- Park the diffs cursor on the current diff (or the first row).
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
	state.context = { file = file_abs, qidx = qidx }
	M.render()
end

function M.refresh()
	state.files = M.files_from_quickfix()
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
	-- The hover is this window's own cursorline. Never inherit the code
	-- window's cursorline: that painted a second, duplicated hover.
	-- No extmarks anywhere (their end_row is inclusive and bled below).
	vim.wo[win].cursorline = true
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

function M.toggle()
	if M.is_open() then
		M.close()
		return false
	end
	M.open()
	return true
end

-- Test seam: reset module state between specs.
function M._reset()
	M.close()
	state.files = {}
	state.context = { file = nil, qidx = nil }
	state.file_rowmap = {}
	state.diff_rowmap = {}
end

return M
