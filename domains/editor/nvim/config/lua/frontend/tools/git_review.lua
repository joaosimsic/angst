---@type Hydra
local Hydra = require("common.Hydra")
---@type Logger
local Logger = require("common.Logger")
local review_files = require("frontend.tools.git_review_files")
local hunk_display = require("frontend.tools.git_hunk_display")
local pages = require("frontend.tools.git_review_pages")
local branch = require("frontend.tools.git_review_branch")
local commit = require("frontend.tools.git_review_commit")
local review_range = require("frontend.tools.git_review_range")
local Picker = require("frontend.tools.git_review_picker")

local palette = require("config.theme.palette")
local p = palette.p

-- Minimal code-buffer review: background-only hunk display with
-- always-on side panes (changed files on top, current file's diffs
-- below; the panes highlight without ever taking focus). `j`/`k` stay
-- normal cursor motion. `d` toggles the bg diff (deleted overlay + line
-- bg; added/removed text is real buffer text), `h`/`l` cycle diffs in
-- the same file only, `n` / `N` step files. No floating preview anywhere.
-- `<Tab>` cycles the tabs worktree -> branch -> commit -> worktree;
-- `<S-Tab>` reverses it. Branch/commit always open their full-height
-- picker; selecting a target applies it to the worktree tab and
-- returns there. `t` reopens the applied source's picker. Tab state,
-- applied range and targets persist across hydra exits.

local function gs()
	local ok, gitsigns = pcall(require, "gitsigns")
	if not ok then
		return nil
	end
	return gitsigns
end

local function need_git()
	if vim.b.gitsigns_status_dict ~= nil then
		return true
	end
	vim.notify(
		"Git review: not a git buffer — open a changed file first",
		vim.log.levels.WARN
	)
	return false
end

local function attached_count()
	local count = 0
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].gitsigns_status_dict ~= nil then
			count = count + 1
		end
	end
	return count
end

local function diagnose_empty()
	vim.notify(
		string.format(
			"Git review: no changed files (%d git buffers, cwd %s). Open a repo file and retry.",
			attached_count(),
			vim.fn.getcwd()
		),
		vim.log.levels.WARN
	)
end

-- Never run jumps from inside a pane: step back to code first.
local function leave_pages_win()
	local filetype = vim.bo[vim.api.nvim_get_current_buf()].filetype
	if filetype == "angst-git-files" or filetype == "angst-git-diffs" or filetype == Picker.FILETYPE then
		pcall(vim.cmd, "wincmd p")
	end
end

-- MODE_VAR is the active tab: nil for worktree, branch/commit while
-- their picker is open. APPLIED_VAR is the range displayed by the
-- worktree tab; it survives picker visits and hydra exits.
local function picker_view()
	local mode = vim.g[review_range.MODE_VAR]
	if mode == "branch" then
		return branch
	elseif mode == "commit" then
		return commit
	end
	return nil
end

local function applied_view()
	local applied = vim.g[review_range.APPLIED_VAR]
	if applied == "branch" then
		return branch
	elseif applied == "commit" then
		return commit
	end
	return nil
end

-- Single synchronous collection, one writer, one tick: worktree hunks
-- for attached buffers (gitsigns cache) plus CLI extras (unstaged for
-- unopened files, staged, unpushed, untracked), written as one list.
-- Never calls gitsigns' async setqflist: its completion lands on a
-- later tick and would replace the combined list under us (resetting
-- the index), which surfaced as perpetual "collecting…" and h/l stuck
-- on the first/last diff. Never runs on enter: the pane must not
-- appear uninvited. Never opens a quickfix window (pages replace it):
-- the cclose only clears windows left open from elsewhere.
local function refresh_files()
	review_files.collect()
	pcall(vim.cmd, "cclose")
	pages.refresh()
end

local function ensure_files_or_collect(after)
	if vim.fn.getqflist({ size = 0 }).size > 0 then
		pages.refresh()
		after()
		return
	end
	vim.notify("Git review: collecting changed files…", vim.log.levels.INFO)
	refresh_files()
	if vim.fn.getqflist({ size = 0 }).size == 0 then
		diagnose_empty()
		return
	end
	after()
end

-- h/l cycle diffs in the same file only (one stop per hunk).
-- An empty list collects on demand, then steps. No floating preview:
-- the bg diff plus the list highlight show where you are.
local function entry_jump(dir)
	local view = applied_view()
	if view ~= nil then
		if Picker.is_open() then
			return
		end
		leave_pages_win()
		if view.is_enabled() then
			view.entry_jump(dir)
			if pages.is_open() then
				pages.render_all(view.State.context.file, view.State.context.eidx)
			end
		end
		return
	end
	leave_pages_win()
	ensure_files_or_collect(function()
		local cur_buf = vim.api.nvim_get_current_buf()
		local cur = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(cur_buf), ":p")
		local owned = {}
		for i, item in ipairs(vim.fn.getqflist()) do
			if pages.same_file(item, cur_buf, cur) then
				owned[#owned + 1] = i
			end
		end
		if #owned == 0 then
			vim.notify("Git review: no diffs in this file", vim.log.levels.INFO)
			return
		end
		local idx = vim.fn.getqflist({ idx = 0 }).idx
		local at = nil
		for i, qi in ipairs(owned) do
			if qi == idx then
				at = i
				break
			end
		end
		local target
		if at == nil then
			-- Quickfix index is stale (list was rebuilt under us, e.g.
			-- overlapping fills resetting idx to 1): jumping to an end
			-- of the file strands h/l on first/last forever. Fall back
			-- to the hunk nearest the cursor so every press moves
			-- sanely; ties break in the stepped direction.
			local items = vim.fn.getqflist()
			local curline = vim.fn.line(".")
			target = owned[1]
			local bestd = nil
			for _, qi in ipairs(owned) do
				local lnum = items[qi].lnum or 0
				local d = math.abs(lnum - curline)
				if bestd == nil or d < bestd then
					bestd = d
					target = qi
				elseif d == bestd then
					local tl = items[target].lnum or 0
					if (dir > 0 and lnum > tl) or (dir < 0 and lnum < tl) then
						target = qi
					end
				end
			end
		elseif dir > 0 then
			target = owned[(at % #owned) + 1]
		else
			target = owned[((at - 2) % #owned) + 1]
		end
		vim.cmd("cc " .. target)
		vim.cmd("normal! zz")
		-- The file didn't change, but the diff marker follows anyway.
		if pages.is_open() then
			pages.render_all(cur, target)
		end
	end)
end

local function toggle_hunks()
	if not need_git() then
		return
	end
	if not gs() then
		return
	end
	hunk_display.toggle()
	-- The `d` switch drives gitsigns; re-apply the range overlay so
	-- both surfaces flip together while a range is applied.
	local view = applied_view()
	if view ~= nil then
		view.paint_current()
	end
end

-- Tab cycles the tabs worktree -> branch -> commit -> worktree;
-- S-Tab walks the same list backwards. Branch/commit always open their
-- full-height picker. Selecting a target applies it to the worktree tab
-- and returns there; cancelling restores the previously applied range.
local function show_view_panes(view)
	local context = view.State.context or {}
	pages.close()
	pages.show_range(view.State.entries, view.State.tops, view.State.label)
	pages.open()
	if context.file ~= nil then
		pages.render_all(context.file, context.eidx)
	end
end

local function show_worktree_panes()
	pages.close()
	pages.show_worktree()
	pages.open()
end

local function restore_worktree_tab()
	vim.g[review_range.MODE_VAR] = nil
	local view = applied_view()
	if view ~= nil and view.target() ~= nil and view.activate() then
		show_view_panes(view)
		return
	end
	if view ~= nil then
		view.clear_applied()
	end
	show_worktree_panes()
end

local function enter_view(view)
	local applied = applied_view()
	if applied ~= nil then
		applied.hide()
	end
	vim.g[review_range.MODE_VAR] = view.mode
	pages.close()
	pcall(vim.cmd, "cclose")
	view.open_picker(restore_worktree_tab, function()
		vim.g[review_range.MODE_VAR] = nil
		show_view_panes(view)
	end)
end

local function cycle_source(dir)
	local order = { branch, commit }
	local current = picker_view()
	local index
	if current == nil then
		index = dir > 0 and 1 or #order
	else
		for i, view in ipairs(order) do
			if view == current then
				index = i + (dir > 0 and 1 or -1)
				break
			end
		end
	end
	if current ~= nil then
		current.hide()
	end
	if index == nil or index < 1 or index > #order then
		restore_worktree_tab()
		return
	end
	enter_view(order[index])
end

local function change_target()
	local view = picker_view() or applied_view()
	if view == nil then
		return
	end
	local applied = applied_view()
	if applied ~= nil then
		applied.hide()
	end
	vim.g[review_range.MODE_VAR] = view.mode
	pages.close()
	pcall(vim.cmd, "cclose")
	view.open_picker(restore_worktree_tab, function()
		vim.g[review_range.MODE_VAR] = nil
		show_view_panes(view)
	end)
end

local function next_source()
	cycle_source(1)
end

local function prev_source()
	cycle_source(-1)
end

-- Jump to the first quickfix entry of `abs_path` (cc index).
---@param abs_path string
---@return integer|nil landed quickfix index
local function jump_to_file(abs_path)
	local target_buf = pages.bufnr_for(abs_path)
	for i, item in ipairs(vim.fn.getqflist()) do
		if pages.same_file(item, target_buf, abs_path) then
			vim.cmd("cc " .. i)
			vim.cmd("normal! zz")
			return i
		end
	end
	return nil
end

-- n/N step files in quickfix order (one stop per file).
local function next_file()
	local view = applied_view()
	if view ~= nil then
		if Picker.is_open() then
			return
		end
		leave_pages_win()
		if view.is_enabled() then
			view.next_file()
			if pages.is_open() then
				pages.render_all(view.State.context.file, view.State.context.eidx)
			end
		end
		return
	end
	leave_pages_win()
	ensure_files_or_collect(function()
		if not pages.is_open() then
			pages.show_worktree()
			pages.open()
		end
		local files = pages.ordered_files()
		if #files == 0 then
			return
		end
		local cur = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
		local pos = 0
		for i, f in ipairs(files) do
			if f == cur then
				pos = i
				break
			end
		end
		local target = files[(pos % #files) + 1]
		local landed = jump_to_file(target)
		if landed ~= nil and pages.is_open() then
			pages.render_all(target, landed)
		end
	end)
end

local function prev_file()
	local view = applied_view()
	if view ~= nil then
		if Picker.is_open() then
			return
		end
		leave_pages_win()
		if view.is_enabled() then
			view.prev_file()
			if pages.is_open() then
				pages.render_all(view.State.context.file, view.State.context.eidx)
			end
		end
		return
	end
	leave_pages_win()
	ensure_files_or_collect(function()
		if not pages.is_open() then
			pages.show_worktree()
			pages.open()
		end
		local files = pages.ordered_files()
		if #files == 0 then
			return
		end
		local cur = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
		local pos = 0
		for i, f in ipairs(files) do
			if f == cur then
				pos = i
				break
			end
		end
		local target = files[((pos - 2) % #files) + 1]
		local landed = jump_to_file(target)
		if landed ~= nil and pages.is_open() then
			pages.render_all(target, landed)
		end
	end)
end

local function setup()
	local logger = Logger.new("GIT:HYDRA")

	Hydra.new({
		name = "Git",
		fg_color = p.background.variant,
		bg_color = p.accent.base,
		enter = "<leader>g",
		global = true,
		persist = true,
		keep_insert_filetypes = { Picker.FILETYPE },
		logger = logger,
		on_enter = function()
			-- The panes open with the hydra (empty placeholders until
			-- the first collect); the quickfix window never appears.
			-- Collection stays lazy: it happens on first n/N/h/l via
			-- ensure_files_or_collect, never on enter.
			-- The active tab and applied range persist in vim.g across
			-- hydra exits: re-enter restores the picker or the applied
			-- range on the worktree tab.
			-- Respect the global hunk switch (default-on): toggles are
			-- global and may have changed since the last session.
			-- Hint stays hidden: `?` toggles the help float.
			-- `j`/`k` are intentionally unbound: normal motion.
			hunk_display.apply()
			pcall(vim.cmd, "cclose")
			local view = picker_view()
			if view ~= nil then
				enter_view(view)
			else
				restore_worktree_tab()
			end
		end,
		on_exit = function()
			pages.close()
			-- Visible quit: pane/picker windows close, but the active
			-- tab, applied range and targets persist so the next enter
			-- restores them. Badge and code tints stay as the indicator.
			Picker.close()
			pcall(vim.cmd, "cclose")
		end,
		heads = {
			{ "d", toggle_hunks, "Diff bg on/off" },
			{ "<Tab>", next_source, "Next diff source" },
			{ "<S-Tab>", prev_source, "Previous diff source" },
			{ "t", change_target, "Change diff target" },
			{ "h", function() entry_jump(-1) end, "Prev diff" },
			{ "l", function() entry_jump(1) end, "Next diff" },
			{ "n", next_file, "Next file" },
			{ "N", prev_file, "Prev file" },
			{
				"q",
				function() end,
				"Quit review",
				exit = true,
			},
		},
		exit_keys = { "<Esc>", "<C-c>" },
	})
end

---@type Plugin
return {
	"git-review",
	virtual = true,
	event = "VeryLazy",
	config = function()
		setup()
	end,
}
