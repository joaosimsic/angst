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
---@param prefix string "Staged" | "Unstaged" | "Unpushed"
---@return ReviewExtraEntry[]
local function parse_diff(toplevel, diff_args, prefix)
	local cmd = { "-c", "core.quotepath=false", "diff", "--no-color", "--no-ext-diff", "-U0" }
	vim.list_extend(cmd, diff_args)

	local entries = {}
	local path = nil
	local pending_a, pending_c, sample = nil, nil, nil

	local function flush()
		if path ~= nil and pending_c ~= nil then
			entries[#entries + 1] = {
				filename = path,
				lnum = pending_c,
				text = ("%s (-%s +%s)%s"):format(
					prefix,
					pending_a or "?",
					pending_c,
					sample and (": " .. sample) or ""
				),
			}
		end
		pending_a, pending_c, sample = nil, nil, nil
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
			local a, c = line:match("^@@ %-(%d+)[,]?%d* %+(%d+)[,]?%d* @@")
			if a then
				flush()
				pending_a, pending_c = a, tonumber(c)
			elseif pending_c and not sample and line:sub(1, 1) == "+" then
				sample = line:sub(2, 120)
			end
		end
	end
	flush()
	return entries
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
				entries[#entries + 1] = {
					filename = toplevel .. "/" .. rel,
					lnum = 1,
					text = "Untracked",
				}
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
						local kind = h.type == "add" and "Added"
							or h.type == "delete" and "Removed" or "Changed"
						local added, removed = nil, nil
						if type(h.lines) == "table" then
							for _, l in ipairs(h.lines) do
								if type(l) == "string" then
									if l:sub(1, 1) == "+" and added == nil then
										added = l:sub(2, 120)
									elseif l:sub(1, 1) == "-" and removed == nil then
										removed = l:sub(2, 120)
									end
								end
							end
						end
						local sample = added or removed
						local function span(n)
							return n ~= 1 and "," .. tostring(n) or ""
						end
						entries[#entries + 1] = {
							bufnr = buf,
							lnum = h.added.start > 0 and h.added.start or 1,
							text = ("%s (-%s%s +%s%s)%s"):format(
								kind,
								tostring(h.removed.start),
								span(h.removed.count),
								tostring(h.added.start),
								span(h.added.count),
								sample and (": " .. sample) or ""
							),
						}
					end
				end
			end
		end
	end
	return entries
end

---@param toplevels string[]
---@return ReviewExtraEntry[] unstaged + staged + unpushed + untracked entries
function M.extra_entries_for(toplevels)
	local entries = {}
	for _, top in ipairs(toplevels) do
		-- Unstaged first: it mirrors the open buffer, so on overlap
		-- lines it wins the file+lnum dedupe over staged below.
		for _, e in ipairs(parse_diff(top, {}, "Unstaged")) do
			entries[#entries + 1] = e
		end
		for _, e in ipairs(parse_diff(top, { "--cached" }, "Staged")) do
			entries[#entries + 1] = e
		end
		local base = unpushed_base(top)
		if base then
			for _, e in ipairs(parse_diff(top, { base .. "..HEAD" }, "Unpushed")) do
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
