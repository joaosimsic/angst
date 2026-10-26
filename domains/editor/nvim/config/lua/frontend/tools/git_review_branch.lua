-- Branch-diff column for the Git review hydra (Tab toggle).
--
-- Same shape and behavior as git_review_pages (right-side column, 70%
-- files on top / 30% diffs below, `n`/`N` step files, `h`/`l` cycle
-- diffs in the current file, focus never leaves the code window), but
-- sourced from the branch range `target...HEAD` instead of the
-- worktree quickfix list. It replaces the whole worktree column while
-- active: the hydra closes the worktree panes on enable and reopens
-- them on disable.
--
-- Session persistence lives in vim.g (`angst_git_branch_diff_enabled`
-- + `angst_git_branch_diff_target`), so the mode survives hydra exits:
-- on_enter reopens the branch column, on_exit leaves it open until Tab
-- disables it again. Entries live in module state, never in the
-- quickfix list, so toggling never clobbers the worktree collection.
local M = {}

local Badge = require("common.Badge")
local palette = require("config.theme.palette")
local branch_hunks = require("frontend.tools.git_branch_hunks")

M.PANE_WIDTH = 30
M.FILES_SHARE = 0.7
M.FILES_FILETYPE = "angst-git-branch-files"
M.DIFFS_FILETYPE = "angst-git-branch-diffs"

M.FILES_HEADER = "BRANCH FILES"
M.DIFFS_HEADER = "BRANCH DIFFS"
M.FILES_EMPTY = "(no branch changes)"
M.DIFFS_EMPTY = "(no diffs)"

M.ENABLED_VAR = "angst_git_branch_diff_enabled"
M.TARGET_VAR = "angst_git_branch_diff_target"

-- Test seam: when set, pick_target calls it with the confirm callback
-- instead of opening fzf/vim.ui.select (both need user input).
M._pick_override = nil

-- Markdown-style floating badge: shows the compared-against branch
-- while the mode persists, hidden again on disable.
local badge = Badge.new({
	name = "git-branch-diff",
	fg = palette.p.background.base,
	bg = palette.p.surface.base,
})
M._badge = badge

-- Same compact-row tints as the worktree panes; no new theme groups.
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
	files_win = nil,
	files_buf = nil,
	diffs_win = nil,
	diffs_buf = nil,
	entries = {},
	files = {},
	tops = {},
	target = nil,
	context = { file = nil, eidx = nil },
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
function M.is_enabled()
	return vim.g[M.ENABLED_VAR] == true and type(vim.g[M.TARGET_VAR]) == "string" and vim.g[M.TARGET_VAR] ~= ""
end

---@return string?
function M.target()
	if M.is_enabled() then
		return vim.g[M.TARGET_VAR]
	end
	return state.target
end

---@param target string
function M.enable(target)
	vim.g[M.TARGET_VAR] = target
	vim.g[M.ENABLED_VAR] = true
	state.target = target
end

function M.disable()
	vim.g[M.ENABLED_VAR] = false
	vim.g[M.TARGET_VAR] = nil
	state.target = nil
	state.entries = {}
	state.files = {}
	state.context = { file = nil, eidx = nil }
	badge:hide("git-branch-diff")
	branch_hunks.clear_all()
end

---@return boolean
function M.is_open()
	return valid_win(state.files_win)
		and valid_buf(state.files_buf)
		and valid_win(state.diffs_win)
		and valid_buf(state.diffs_buf)
end

---@return table[] { filename = abs path, lnum = int }
function M.ordered_files()
	return state.files
end

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

---@param entry table
---@param bufnr? integer
---@param abs_path string
function M.same_file(entry, bufnr, abs_path)
	local name = entry.filename
	if name == nil or name == "" then
		return false
	end
	return vim.fn.fnamemodify(name, ":p") == abs_path
end

-- Branch entries (one per diff) for `abs_path`, in collection order.
---@param abs_path string
---@return table[] { eidx = entries index, lnum = int|string, text = string }
local function owned_entries(abs_path)
	local bufnr = M.bufnr_for(abs_path)
	local out = {}
	for i, entry in ipairs(state.entries) do
		if M.same_file(entry, bufnr, abs_path) then
			out[#out + 1] = {
				eidx = i,
				lnum = entry.lnum and entry.lnum > 0 and entry.lnum or "?",
				text = entry.text or "",
			}
		end
	end
	return out
end

---@param cb fun(target: string|nil)
function M.pick_target(cb)
	if M._pick_override ~= nil then
		M._pick_override(cb)
		return
	end
	local review_files = package.loaded["frontend.tools.git_review_files"]
	if review_files == nil then
		local ok, mod = pcall(require, "frontend.tools.git_review_files")
		if ok then
			review_files = mod
		end
	end
	local tops = {}
	if type(review_files) == "table" and type(review_files.repo_toplevels) == "function" then
		local ok, res = pcall(review_files.repo_toplevels)
		if ok and type(res) == "table" then
			tops = res
		end
	end
	local cwd = tops[1] or vim.fn.getcwd()
	local branches = {}
	if type(review_files) == "table" and type(review_files.list_branches) == "function" then
		local ok, res = pcall(review_files.list_branches, cwd)
		if ok and type(res) == "table" then
			branches = res
		end
	end
	-- Comparing a branch against itself is always empty: drop the
	-- current branch (and its remote tracking twin) from the choices.
	local own = nil
	if type(review_files) == "table" and type(review_files.current_branch) == "function" then
		local ok, res = pcall(review_files.current_branch, cwd)
		if ok and type(res) == "string" and res ~= "" then
			own = res
		end
	end
	if own ~= nil then
		local kept = {}
		for _, b in ipairs(branches) do
			if b ~= own and b ~= "origin/" .. own then
				kept[#kept + 1] = b
			end
		end
		branches = kept
	end
	if #branches == 0 then
		vim.notify("Git branch diff: no other branches found", vim.log.levels.WARN)
		cb(nil)
		return
	end
	-- Preselect the stored target so Tab off/on keeps the same branch.
	local current = vim.g[M.TARGET_VAR]
	local ok_fzf, fzf = pcall(require, "fzf-lua")
	if ok_fzf and type(fzf) == "table" and type(fzf.fzf_exec) == "function" then
		fzf.fzf_exec(branches, {
			prompt = "Branch diff> ",
			winopts = { height = 0.40, width = 0.50 },
			actions = {
				["default"] = function(selected)
					cb(selected and selected[1] or nil)
				end,
			},
		})
		return
	end
	vim.ui.select(branches, {
		prompt = "Branch diff target:",
		format_item = function(item)
			if item == current then
				return item .. " (current target)"
			end
			return item
		end,
	}, function(choice)
		cb(choice)
	end)
end

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
	local label = M.target() or state.target or "?"
	set_winbar(state.files_win, string.format("▸ %s · %s (%d)", M.FILES_HEADER, label, #state.files))
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
		local current = d.eidx == state.context.eidx
		if current then
			marked = #lines + 1
		end
		lines[#lines + 1] = (current and "> " or "  ") .. d.text
		state.diff_rowmap[#lines] = d.eidx
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

-- Bg-tint overlay for the current file's branch hunks. Skips the
-- sidebar panes themselves; their filetypes never hold branch hunks.
function M.paint_current()
	if not M.is_enabled() then
		return
	end
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype
	if ft == M.FILES_FILETYPE or ft == M.DIFFS_FILETYPE then
		return
	end
	local abs = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
	if abs == "" then
		return
	end
	local hunks = {}
	for _, e in ipairs(state.entries) do
		if M.same_file(e, bufnr, abs) then
			hunks[#hunks + 1] = { lnum = e.lnum, text = e.text }
		end
	end
	branch_hunks.paint(bufnr, hunks)
end

local autocmd_ready = false
local function ensure_autocmd()
	if autocmd_ready then
		return
	end
	autocmd_ready = true
	local group = vim.api.nvim_create_augroup("GitReviewBranchHunks", { clear = true })
	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function()
			M.paint_current()
		end,
	})
end

---@param file_abs? string
---@param eidx? integer
function M.render_all(file_abs, eidx)
	state.context = { file = file_abs, eidx = eidx }
	M.render()
	M.paint_current()
end

-- Synchronous collection for `target`: toplevels plus branch entries
-- plus the deduped file list. Never touches the quickfix list.
---@param target string
---@return string[] tops, table[] entries, table[] files
local function collect_entries(target)
	local review_files = package.loaded["frontend.tools.git_review_files"]
	if review_files == nil then
		review_files = require("frontend.tools.git_review_files")
	end
	local tops = {}
	if type(review_files.repo_toplevels) == "function" then
		local ok, res = pcall(review_files.repo_toplevels)
		if ok and type(res) == "table" then
			tops = res
		end
	end
	local entries = {}
	if type(review_files.branch_entries_for) == "function" then
		local ok, res = pcall(review_files.branch_entries_for, tops, target)
		if ok and type(res) == "table" then
			entries = res
		end
	end
	local files, seen = {}, {}
	for _, e in ipairs(entries) do
		local abs = vim.fn.fnamemodify(e.filename, ":p")
		if not seen[abs] then
			seen[abs] = true
			files[#files + 1] = { filename = abs, lnum = e.lnum and e.lnum > 0 and e.lnum or 1 }
		end
	end
	return tops, entries, files
end

function M.refresh()
	local target = M.target() or state.target
	if target == nil or target == "" then
		return
	end
	local tops, entries, files = collect_entries(target)
	state.tops = tops
	state.entries = entries
	state.target = target
	state.files = files
	M.render()
end

---@param entry table|nil { filename, lnum }
---@return boolean
local function goto_entry(entry)
	if entry == nil then
		return false
	end
	local cur = vim.api.nvim_get_current_win()
	if cur == state.files_win or cur == state.diffs_win then
		pcall(vim.cmd, "wincmd p")
	end
	local lnum = entry.lnum and entry.lnum > 0 and entry.lnum or 1
	local abs = vim.fn.fnamemodify(entry.filename, ":p")
	local cur_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()), ":p")
	if cur_name ~= abs then
		local ok = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(entry.filename))
		if not ok then
			vim.notify("Git branch diff: cannot open " .. entry.filename, vim.log.levels.WARN)
			return false
		end
	end
	pcall(vim.api.nvim_win_set_cursor, 0, { lnum, 0 })
	pcall(vim.cmd, "normal! zz")
	return true
end

---@param dir integer +1 next, -1 prev
function M.entry_jump(dir)
	if not M.is_enabled() then
		return
	end
	if not M.is_open() then
		M.open()
	end
	-- open() auto-disables on empty ranges (with its own notice).
	if not M.is_enabled() then
		return
	end
	if #state.entries == 0 then
		M.refresh()
	end
	if #state.entries == 0 then
		vim.notify("Git branch diff: no changes", vim.log.levels.INFO)
		return
	end
	local cur_buf = vim.api.nvim_get_current_buf()
	local cur = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(cur_buf), ":p")
	local owned = {}
	for i, entry in ipairs(state.entries) do
		if M.same_file(entry, cur_buf, cur) then
			owned[#owned + 1] = i
		end
	end
	if #owned == 0 then
		vim.notify("Git branch diff: no diffs in this file", vim.log.levels.INFO)
		return
	end
	local at = nil
	for i, ei in ipairs(owned) do
		if ei == state.context.eidx then
			at = i
			break
		end
	end
	local target_eidx
	if at == nil then
		local curline = vim.fn.line(".")
		target_eidx = owned[1]
		local bestd = nil
		for _, ei in ipairs(owned) do
			local lnum = state.entries[ei].lnum or 0
			local d = math.abs(lnum - curline)
			if bestd == nil or d < bestd then
				bestd = d
				target_eidx = ei
			elseif d == bestd then
				local tl = state.entries[target_eidx].lnum or 0
				if (dir > 0 and lnum > tl) or (dir < 0 and lnum < tl) then
					target_eidx = ei
				end
			end
		end
	elseif dir > 0 then
		target_eidx = owned[(at % #owned) + 1]
	else
		target_eidx = owned[((at - 2) % #owned) + 1]
	end
	if goto_entry(state.entries[target_eidx]) then
		M.render_all(cur, target_eidx)
	end
end

-- Jump to the first branch entry of `abs_path`.
---@param abs_path string
---@return integer|nil landed entries index
local function jump_to_file(abs_path)
	for i, entry in ipairs(state.entries) do
		if M.same_file(entry, M.bufnr_for(abs_path), abs_path) then
			if goto_entry(entry) then
				return i
			end
			return nil
		end
	end
	return nil
end

function M.next_file()
	if not M.is_enabled() then
		return
	end
	if not M.is_open() then
		M.open()
	end
	-- open() auto-disables on empty ranges (with its own notice).
	if not M.is_enabled() then
		return
	end
	if #state.files == 0 then
		M.refresh()
	end
	if #state.files == 0 then
		return
	end
	local cur = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
	local pos = 0
	for i, f in ipairs(state.files) do
		if f.filename == cur then
			pos = i
			break
		end
	end
	local target = state.files[(pos % #state.files) + 1].filename
	local landed = jump_to_file(target)
	if landed ~= nil then
		M.render_all(target, landed)
	end
end

function M.prev_file()
	if not M.is_enabled() then
		return
	end
	if not M.is_open() then
		M.open()
	end
	-- open() auto-disables on empty ranges (with its own notice).
	if not M.is_enabled() then
		return
	end
	if #state.files == 0 then
		M.refresh()
	end
	if #state.files == 0 then
		return
	end
	local cur = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
	local pos = 0
	for i, f in ipairs(state.files) do
		if f.filename == cur then
			pos = i
			break
		end
	end
	local target = state.files[((pos - 2) % #state.files) + 1].filename
	local landed = jump_to_file(target)
	if landed ~= nil then
		M.render_all(target, landed)
	end
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
		local entry = state.entries[target]
		if entry ~= nil and goto_entry(entry) then
			M.render_all(vim.fn.fnamemodify(entry.filename, ":p"), target)
		end
	elseif target ~= nil then
		local landed = jump_to_file(target)
		if landed ~= nil then
			M.render_all(target, landed)
		end
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
	vim.wo[win].wrap = true
	pcall(vim.api.nvim_win_set_option, win, "showbreak", "  ")
	vim.wo[win].cursorline = true
	pcall(vim.api.nvim_win_set_option, win, "winhighlight", "CursorLine:GitReviewCursor")
	pcall(vim.api.nvim_win_set_option, win, "statusline", " ")
end

-- A normal code window (not a sidebar pane, not a float): the only
-- safe place to park focus after (re)building the column.
---@param win integer|nil
---@return boolean
local function is_code_win(win)
	if not valid_win(win) then
		return false
	end
	if win == state.files_win or win == state.diffs_win then
		return false
	end
	local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
	if not ok or (cfg.relative ~= nil and cfg.relative ~= "") then
		return false
	end
	local buf = vim.api.nvim_win_get_buf(win)
	local ft = vim.bo[buf].filetype
	return ft ~= M.FILES_FILETYPE and ft ~= M.DIFFS_FILETYPE
end

---@param target? string branch to diff against (defaults to the stored target)
---@return integer|nil files window, nil when the range is empty (auto-disabled)
function M.open(target)
	if target ~= nil and target ~= "" then
		M.enable(target)
	end
	local active = M.target() or state.target
	if active == nil or active == "" then
		return nil
	end
	-- Collect before building windows: an empty range (bad target,
	-- self-compare, merged away) auto-disables with a clear notice
	-- instead of stranding navigation on placeholders.
	local tops, entries, files = collect_entries(active)
	if #entries == 0 then
		vim.notify(
			string.format("Git branch diff: no changes between HEAD and %s", active),
			vim.log.levels.WARN
		)
		M.disable()
		return nil
	end
	ensure_autocmd()
	badge:show("git-branch-diff", "⇄ " .. active)
	state.tops = tops
	state.entries = entries
	state.target = active
	state.files = files
	if M.is_open() then
		M.render()
		M.paint_current()
		return state.files_win
	end
	pcall(vim.cmd, "cclose")
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
	local total = vim.api.nvim_win_get_height(state.files_win) + vim.api.nvim_win_get_height(state.diffs_win) + 1
	pcall(vim.api.nvim_win_set_height, state.files_win, math.max(1, math.floor(total * M.FILES_SHARE)))
	if is_code_win(code_win) then
		pcall(vim.api.nvim_set_current_win, code_win)
	else
		local parked = false
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if is_code_win(win) then
				parked = pcall(vim.api.nvim_set_current_win, win)
				break
			end
		end
		if not parked then
			pcall(vim.cmd, "wincmd p")
		end
	end
	M.render_all(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p"), state.context.eidx)
	-- The current file may sit outside the branch range (e.g. reached
	-- via worktree n/N): say so once instead of leaving h/l mute.
	local cur = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
	local found = false
	for _, f in ipairs(state.files) do
		if f.filename == cur then
			found = true
			break
		end
	end
	if not found and #state.files > 0 then
		vim.notify(
			string.format(
				"Git branch diff: no hunks in this file — n/N jumps to %s",
				vim.fn.fnamemodify(state.files[1].filename, ":t")
			),
			vim.log.levels.INFO
		)
	end
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
	state.entries = {}
	state.files = {}
	state.tops = {}
	state.target = nil
	state.context = { file = nil, eidx = nil }
	state.file_rowmap = {}
	state.diff_rowmap = {}
	state.diffs_match = {}
	M._pick_override = nil
end

return M
