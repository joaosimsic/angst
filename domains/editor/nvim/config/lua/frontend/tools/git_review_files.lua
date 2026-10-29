-- Extra review entries beyond gitsigns' worktree hunks.
--
-- gitsigns only computes hunks for open buffers, so three whole classes
-- of changed files would be unreachable via n/p:
--   unstaged changes in unopened files (no buffer, no hunks),
--   staged-only files (no index->worktree hunks exist for them), and
--   committed-but-unpushed files (clean worktree, changed vs upstream).
-- Untracked files get one stop each so n/N can reach them too.
-- This module builds quickfix entries for all of them via plain git CLI,
-- using only public vim APIs (no gitsigns internals).

local M = {}

---@param cwd string
---@param args string[]
---@return string[] output lines, empty on failure
local function git_lines(cwd, args)
	if vim.fn.executable("git") ~= 1 then
		return {}
	end
	local cmd = { "git", "-C", cwd }
	vim.list_extend(cmd, args)
	local out = vim.fn.systemlist(cmd)
	if vim.v.shell_error ~= 0 then
		return {}
	end
	return out
end

---@return string[] repo toplevels for cwd + open buffers, deduped
function M.repo_toplevels()
	local dirs = { vim.fn.getcwd() }
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= "" then
				dirs[#dirs + 1] = vim.fn.fnamemodify(name, ":p:h")
			end
		end
	end

	local tops, seen = {}, {}
	for _, dir in ipairs(dirs) do
		local lines = git_lines(dir, { "rev-parse", "--show-toplevel" })
		local top = lines[1]
		if top ~= nil and top ~= "" and not seen[top] then
			seen[top] = true
			tops[#tops + 1] = top
		end
	end
	return tops
end

---@class ReviewExtraEntry
---@field filename string absolute path
---@field lnum integer
---@field text string

---@param toplevel string
---@param diff_args string[]
---@return ReviewExtraEntry[] entries with compact "lnum(signN) kind" text
local function parse_diff(toplevel, diff_args)
	local cmd = { "-c", "core.quotepath=false", "diff", "--no-color", "--no-ext-diff", "-U0" }
	vim.list_extend(cmd, diff_args)

	local entries = {}
	local path = nil
	local pending_c, pending_sign, pending_n, pending_kind = nil, nil, nil, nil

	local function flush()
		if path ~= nil and pending_c ~= nil then
			entries[#entries + 1] = {
				filename = path,
				lnum = pending_c,
				text = ("%d: (%s%d) %s"):format(pending_c, pending_sign, pending_n, pending_kind),
			}
		end
		pending_c, pending_sign, pending_n, pending_kind = nil, nil, nil, nil
	end

	for _, line in ipairs(git_lines(toplevel, cmd)) do
		local git_path = line:match("^diff %-%-git a/.+ b/(.+)$")
		if git_path then
			flush()
			path = false
		elseif line:sub(1, 4) == "+++ " then
			local new_path = line:match("^%+%+%+ b/(.+)$")
			if new_path then
				path = toplevel .. "/" .. new_path
			else
				-- /dev/null (deleted) or anything unrecognized: no buffer to show.
				path = nil
			end
		elseif path then
			local a, an_s, c, cm_s = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
			if a then
				flush()
				local an = an_s == "" and 1 or tonumber(an_s)
				local cm = cm_s == "" and 1 or tonumber(cm_s)
				pending_c = tonumber(c)
				if an == 0 then
					pending_sign, pending_n, pending_kind = "+", cm, "A"
				elseif cm == 0 then
					pending_sign, pending_n, pending_kind = "-", an, "D"
				else
					-- Changed hunk: N counts the landing (added) side.
					pending_sign, pending_n, pending_kind = "~", cm, "M"
				end
			end
		end
	end
	flush()
	return entries
end

---@param toplevel string
---@param diff_args string[]
---@return ReviewExtraEntry[] entries with compact "lnum(signN) kind" text
function M.diff_entries_for(toplevel, diff_args)
	return parse_diff(toplevel, diff_args)
end

---@param toplevel string
---@param target string
---@return string? merge-base of HEAD and target, nil when unresolvable
local function branch_base(toplevel, target)
	local mb = git_lines(toplevel, { "merge-base", "HEAD", target })
	if #mb == 0 then
		return nil
	end
	return mb[1]
end

-- Branch-to-branch entries: changes unique to HEAD since it diverged
-- from `target` (`base..HEAD` when a merge-base exists, else
-- `target..HEAD`). Same compact row shape as every other source so the
-- panes tint without new highlight groups.
---@param toplevels string[]
---@param target string
---@return ReviewExtraEntry[]
function M.branch_entries_for(toplevels, target)
	if target == nil or target == "" then
		return {}
	end
	local entries = {}
	for _, top in ipairs(toplevels) do
		local base = branch_base(top, target)
		local range
		if base ~= nil and base ~= "" then
			range = base .. "..HEAD"
		else
			range = target .. "..HEAD"
		end
		for _, e in ipairs(parse_diff(top, { range })) do
			entries[#entries + 1] = e
		end
	end
	return entries
end

---@param cwd? string
---@return string[] local + remote short branch names, deduped
function M.list_branches(cwd)
	local out, seen = {}, {}
	for _, line in ipairs(git_lines(cwd or vim.fn.getcwd(), { "branch", "-a", "--format=%(refname:short)" })) do
		if not line:find(" -> ", 1, true) then
			local b = line:gsub("^%*%s+", ""):gsub("^%s+", ""):gsub("%s+$", "")
			if b ~= "" and b ~= "HEAD" and not seen[b] then
				seen[b] = true
				out[#out + 1] = b
			end
		end
	end
	return out
end

---@param cwd? string
---@return string? current branch name, nil when detached or outside a repo
function M.current_branch(cwd)
	local lines = git_lines(cwd or vim.fn.getcwd(), { "rev-parse", "--abbrev-ref", "HEAD" })
	local b = lines[1]
	if b == nil or b == "" or b == "HEAD" then
		return nil
	end
	return b
end

---@param toplevel string
---@return string? merge-base of HEAD and upstream, nil when nothing unpushed
local function unpushed_base(toplevel)
	local up = git_lines(toplevel, { "rev-parse", "--verify", "@{u}" })
	if #up == 0 then
		return nil
	end
	local mb = git_lines(toplevel, { "merge-base", "HEAD", up[1] })
	if #mb == 0 then
		return nil
	end
	local head = git_lines(toplevel, { "rev-parse", "HEAD" })
	if #head == 0 or mb[1] == head[1] then
		return nil
	end
	return mb[1]
end

---@param toplevel string
---@return ReviewExtraEntry[] one {filename, lnum=1} stop per untracked file
local function untracked_entries(toplevel)
	local entries = {}
	local cmd = { "-c", "core.quotepath=false", "status", "--porcelain", "-uall" }
	for _, line in ipairs(git_lines(toplevel, cmd)) do
		if line:sub(1, 2) == "??" then
			local rel = line:sub(4)
			-- Defensive: strip quotes if quotepath ever kicks back in.
			local unquoted = rel:match('^"(.*)"$')
			if unquoted then
				rel = unquoted
			end
			if rel ~= nil and rel ~= "" then
				local abs = toplevel .. "/" .. rel
				-- Streamed count: no whole-file read for big files.
				-- Unreadable files are skipped, like deleted ones.
				local fh = io.open(abs, "r")
				if fh ~= nil then
					local n = 0
					for _ in fh:lines() do
						n = n + 1
					end
					fh:close()
					entries[#entries + 1] = {
						filename = abs,
						lnum = 1,
						text = ("1: (+%d) ??"):format(n),
					}
				end
			end
		end
	end
	return entries
end

-- Worktree hunks for attached buffers, straight from the gitsigns cache.
-- Synchronous (nil when the buffer isn't attached), so unlike gitsigns'
-- own async setqflist it can join a single combined write with no later
-- tick replacing the list under us.
---@return ReviewExtraEntry[] {bufnr, lnum} stops in buffer-number order
local function worktree_entries()
	local entries = {}
	local ok_gs, gs = pcall(require, "gitsigns")
	if not ok_gs or type(gs) ~= "table" or type(gs.get_hunks) ~= "function" then
		return entries
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
			and vim.api.nvim_buf_get_name(buf) ~= "" then
			local ok, hunks = pcall(gs.get_hunks, buf)
			if ok and type(hunks) == "table" then
				for _, h in ipairs(hunks) do
					if type(h) == "table" and type(h.added) == "table"
						and type(h.removed) == "table" then
						-- Same rule as parse_diff: rc/cm are the removed
						-- and added (landing) side counts; N counts the
						-- landing side, the letter is the hunk kind.
						local rc = tonumber(h.removed.count) or 0
						local ac = tonumber(h.added.count) or 0
						local sign, n, kind
						if rc == 0 then
							sign, n, kind = "+", ac, "A"
						elseif ac == 0 then
							sign, n, kind = "-", rc, "D"
						else
							sign, n, kind = "~", ac, "M"
						end
						local start = tonumber(h.added.start) or 0
						if start <= 0 then
							start = 1
						end
						entries[#entries + 1] = {
							bufnr = buf,
							lnum = start,
							text = ("%d: (%s%d) %s"):format(start, sign, n, kind),
						}
					end
				end
			end
		end
	end
	return entries
end

---@param toplevels string[]
---@return ReviewExtraEntry[] unstaged + staged + unpushed + untracked entries,
---each shaped "lnum: (signN) kind" (e.g. "121: (-4) D", "11: (~5) M")
function M.extra_entries_for(toplevels)
	local entries = {}
	for _, top in ipairs(toplevels) do
		-- Unstaged first: it mirrors the open buffer, so on overlap
		-- lines it wins the file+lnum dedupe over staged below.
		for _, e in ipairs(parse_diff(top, {})) do
			entries[#entries + 1] = e
		end
		for _, e in ipairs(parse_diff(top, { "--cached" })) do
			entries[#entries + 1] = e
		end
		local base = unpushed_base(top)
		if base then
			for _, e in ipairs(parse_diff(top, { base .. "..HEAD" })) do
				entries[#entries + 1] = e
			end
		end
		for _, e in ipairs(untracked_entries(top)) do
			entries[#entries + 1] = e
		end
	end
	return entries
end

-- Per-hunk dedupe (file + lnum): one stop per hunk. A staged file
-- with N hunks must contribute N entries, not one. Entries at a
-- lnum already covered are skipped to avoid double stops on the same
-- line; exact dupes from overlapping refreshes are skipped the same way.
local function key_for(abs_path, lnum)
	return abs_path .. "\0" .. tostring(lnum or 0)
end

---@param entry table quickfix-shaped {bufnr?|filename?, lnum?}
---@return string? absolute path, nil when unresolvable
local function abs_of(entry)
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

---@param entries ReviewExtraEntry[]
---@return integer number of entries appended
function M.append_missing(entries)
	local listed = {}
	for _, item in ipairs(vim.fn.getqflist()) do
		local abs = abs_of(item)
		if abs ~= nil then
			listed[key_for(abs, item.lnum)] = true
		end
	end

	local fresh = {}
	for _, e in ipairs(entries) do
		local key = key_for(vim.fn.fnamemodify(e.filename, ":p"), e.lnum)
		if not listed[key] then
			listed[key] = true
			fresh[#fresh + 1] = { filename = e.filename, lnum = e.lnum, col = 1, text = e.text }
		end
	end

	if #fresh > 0 then
		vim.fn.setqflist(fresh, "a")
	end
	return #fresh
end

-- Single synchronous collection: worktree hunks for attached buffers
-- first, then CLI extras (unstaged/staged/unpushed/untracked, covering
-- unopened files). Written as one list in one tick: unlike gitsigns'
-- async setqflist, no later tick can replace the combined list under
-- us and reset the index, which surfaced as perpetual "collecting…"
-- and h/l stuck on the first/last diff.
---@return integer number of entries in the rebuilt list
function M.collect()
	local combined, seen = {}, {}
	local function offer(entry)
		local abs = abs_of(entry)
		if abs == nil then
			return
		end
		local key = key_for(abs, entry.lnum)
		if seen[key] then
			return
		end
		seen[key] = true
		combined[#combined + 1] = {
			bufnr = entry.bufnr,
			filename = entry.filename,
			lnum = entry.lnum,
			col = entry.col or 1,
			text = entry.text,
		}
	end
	for _, e in ipairs(worktree_entries()) do
		offer(e)
	end
	for _, e in ipairs(M.extra_entries_for(M.repo_toplevels())) do
		offer(e)
	end
	vim.fn.setqflist(combined, "r")
	return #combined
end

return M
