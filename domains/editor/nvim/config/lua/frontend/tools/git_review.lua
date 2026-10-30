---@type Hydra
local Hydra = require("common.Hydra")
---@type Logger
local Logger = require("common.Logger")
local review_files = require("frontend.tools.git_review_files")
local hunk_display = require("frontend.tools.git_hunk_display")
local pages = require("frontend.tools.git_review_pages")
local branch = require("frontend.tools.git_review_branch")

local palette = require("config.theme.palette")
local p = palette.p

-- Minimal code-buffer review: background-only hunk display with
-- always-on side panes (changed files on top, current file's diffs
-- below; the panes highlight without ever taking focus). `j`/`k` stay
-- normal cursor motion. `d` toggles the bg diff (deleted overlay + line
-- bg; added/removed text is real buffer text), `h`/`l` cycle diffs in
-- the same file only, `n` / `N` step files. No floating preview anywhere.
-- `<Tab>` swaps the whole column to a branch-diff view (current branch
-- vs a picked branch) that persists across hydra exits until `<Tab>`
-- disables it again.

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
	-- open() leaves focus in code, but the user may have moved
	-- into a pane with `wincmd l`: come back before jumping.
	-- Branch panes replace the whole column, so they count too.
	local filetype = vim.bo[vim.api.nvim_get_current_buf()].filetype
	if
		filetype == "angst-git-files"
		or filetype == "angst-git-diffs"
		or filetype == "angst-git-branch-files"
		or filetype == "angst-git-branch-diffs"
	then
		pcall(vim.cmd, "wincmd p")
	end
end

-- Branch-diff mode replaces the whole column: while enabled, h/l and
-- n/N navigate branch entries (never the worktree quickfix), and the
-- mode survives hydra exits via vim.g until Tab disables it again.
local function branch_mode()
	return branch.is_enabled()
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
	leave_pages_win()
	if branch_mode() then
		branch.entry_jump(dir)
		return
	end
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
	-- The `d` switch drives gitsigns; re-apply the branch overlay so
	-- both surfaces flip together while branch mode is active.
	if branch_mode() then
		branch.paint_current()
	end
end

-- Tab toggles the branch-diff column: enable picks the other branch
-- once, then the whole sidebar shows branch files/diffs until Tab
-- disables it again. Enable/disable swaps the column immediately;
-- the vim.g flag keeps the mode across hydra exits.
local function toggle_branch_diff()
	if branch.is_enabled() then
		branch.disable()
		branch.close()
		pcall(vim.cmd, "cclose")
		if vim.g.active_hydra ~= nil and vim.g.active_hydra.name == "Git" then
			pages.open()
		end
		vim.notify("Git branch diff off", vim.log.levels.INFO)
		return
	end
	branch.pick_target(function(target)
		if target == nil or target == "" then
			return
		end
		pages.close()
		pcall(vim.cmd, "cclose")
		-- Empty ranges auto-disable inside open() (with their own
		-- notice); fall back to the worktree panes then.
		if branch.open(target) == nil then
			if vim.g.active_hydra ~= nil and vim.g.active_hydra.name == "Git" then
				pages.open()
			end
			return
		end
		vim.notify("Git branch diff vs " .. target, vim.log.levels.INFO)
	end)
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
	leave_pages_win()
	if branch_mode() then
		branch.next_file()
		return
	end
	ensure_files_or_collect(function()
		if not pages.is_open() then
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
	leave_pages_win()
	if branch_mode() then
		branch.prev_file()
		return
	end
	ensure_files_or_collect(function()
		if not pages.is_open() then
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
		logger = logger,
		on_enter = function()
			-- The panes open with the hydra (empty placeholders until
			-- the first collect); the quickfix window never appears.
			-- Collection stays lazy: it happens on first n/N/h/l via
			-- ensure_files_or_collect, never on enter.
			-- Branch-diff mode replaces the whole column and persists
			-- in vim.g across hydra exits: re-enter reopens it instead
			-- of the worktree panes until Tab disables it.
			-- Respect the global hunk switch (default-on): toggles are
			-- global and may have changed since the last session.
			-- Hint stays hidden: `?` toggles the help float.
			-- `j`/`k` are intentionally unbound: normal motion.
			hunk_display.apply()
			pcall(vim.cmd, "cclose")
			if branch.is_enabled() then
				-- A stale enable (e.g. target merged away) auto-disables
				-- inside open(); fall back to the worktree panes then.
				if branch.open() == nil then
					pages.open()
				end
			else
				pages.open()
			end
		end,
		on_exit = function()
			pages.close()
			-- Visible quit: the branch column always closes, but the
			-- enabled flag and target persist so the next enter
			-- restores it until Tab disables it. Badge and code
			-- tints stay as the persisted-mode indicator.
			branch.close()
			pcall(vim.cmd, "cclose")
		end,
		heads = {
			{ "d", toggle_hunks, "Diff bg on/off" },
			{ "<Tab>", toggle_branch_diff, "Branch diff on/off" },
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
