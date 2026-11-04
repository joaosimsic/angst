-- Shared range source for the Git review hydra.
--
-- An instance collects branch/commit range entries, shows the badge and
-- paints the bg-only code overlay. The shared FILES/DIFFS panes display
-- the range entries; h/l/n/N walk them while the overlay marks the code.
local M = {}

local Badge = require("common.Badge")
local palette = require("config.theme.palette")
local Picker = require("frontend.tools.git_review_picker")
local range_hunks = require("frontend.tools.git_range_hunks")
local review_files = require("frontend.tools.git_review_files")

M.MODE_VAR = "angst_git_review_mode"
M.APPLIED_VAR = "angst_git_review_applied"

-- opts:
--   mode, target_var, badge_name, badge_label(target)
--   picker_title, picker_empty
--   list_targets(cwd), filter_target(items, query), resolve_target(cwd, query)
--   entries_for(toplevels, target), empty_range_notice(target)
---@param opts table
---@return table
function M.new(opts)
	local state = {
		entries = {},
		files = {},
		tops = {},
		label = nil,
		context = { file = nil, eidx = nil },
	}

	local self = {
		mode = opts.mode,
		target_var = opts.target_var,
		State = state,
	}

	local badge = Badge.new({
		name = opts.badge_name,
		fg = palette.p.background.base,
		bg = palette.p.surface.base,
	})
	self._badge = badge

	---@return boolean
	function self.is_active()
		return vim.g[M.MODE_VAR] == self.mode
	end

	---@return string?
	function self.target()
		local target = vim.g[self.target_var]
		if type(target) == "string" and target ~= "" then
			return target
		end
		return nil
	end

	---@param target string
	function self.set_target(target)
		vim.g[self.target_var] = target
	end

	function self.clear_target()
		vim.g[self.target_var] = nil
	end

	---@return boolean
	function self.is_applied()
		return vim.g[M.APPLIED_VAR] == self.mode and self.target() ~= nil
	end

	function self.clear_applied()
		if vim.g[M.APPLIED_VAR] == self.mode then
			vim.g[M.APPLIED_VAR] = nil
		end
	end

	---@return boolean
	function self.is_enabled()
		return self.is_applied()
	end

	local function hide_badge()
		badge:hide(opts.badge_name)
	end

	function self.hide()
		Picker.close()
		hide_badge()
		range_hunks.clear_all()
		state.context = { file = nil, eidx = nil }
	end

	function self.disable()
		self.hide()
		self.clear_target()
		self.clear_applied()
		if self.is_active() then
			vim.g[M.MODE_VAR] = nil
		end
	end

	---@return table[] { filename = abs path, lnum = int }
	function self.ordered_files()
		return state.files
	end

	---@param abs_path string
	---@return integer|nil
	function self.bufnr_for(abs_path)
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
	function self.same_file(entry, bufnr, abs_path)
		local name = entry.filename
		if name == nil or name == "" then
			return false
		end
		return vim.fn.fnamemodify(name, ":p") == abs_path
	end

	-- Bg-tint overlay for the current file's range hunks. Skips the
	-- worktree sidebar panes and the picker.
	function self.paint_current()
		if not self.is_enabled() or Picker.is_open() then
			return
		end
		local bufnr = vim.api.nvim_get_current_buf()
		local ft = vim.bo[bufnr].filetype
		if ft == "angst-git-files" or ft == "angst-git-diffs" or ft == Picker.FILETYPE then
			return
		end
		local abs = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
		if abs == "" then
			return
		end
		local hunks = {}
		for _, e in ipairs(state.entries) do
			if self.same_file(e, bufnr, abs) then
				hunks[#hunks + 1] = { lnum = e.lnum, text = e.text }
			end
		end
		range_hunks.paint(bufnr, hunks)
	end

	local autocmd_ready = false
	local function ensure_autocmd()
		if autocmd_ready then
			return
		end
		autocmd_ready = true
		local group = vim.api.nvim_create_augroup("GitReviewRangeHunks_" .. self.mode, { clear = true })
		vim.api.nvim_create_autocmd("BufEnter", {
			group = group,
			callback = function()
				self.paint_current()
			end,
		})
	end

	-- Synchronous collection for `target`: toplevels plus range entries
	-- plus the deduped file list. Never touches the quickfix list.
	---@param target string
	---@return string[] tops, table[] entries, table[] files
	local function collect_entries(target)
		local tops = {}
		local ok_tops, res = pcall(review_files.repo_toplevels)
		if ok_tops and type(res) == "table" then
			tops = res
		end
		local entries = {}
		local ok_entries, collected = pcall(opts.entries_for, tops, target)
		if ok_entries and type(collected) == "table" then
			entries = collected
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

	-- Apply a target range without opening any sidebar: badge + entries
	-- + code overlay only. Returns false when the range is empty.
	---@param target? string
	---@return boolean
	function self.activate(target)
		if target ~= nil and target ~= "" then
			self.set_target(target)
		end
		local active = self.target()
		if active == nil then
			return false
		end
		local tops, entries, files = collect_entries(active)
		if #entries == 0 then
			hide_badge()
			range_hunks.clear_all()
			vim.notify(opts.empty_range_notice(active), vim.log.levels.WARN)
			return false
		end
		Picker.close()
		ensure_autocmd()
		vim.g[M.APPLIED_VAR] = self.mode
		badge:show(opts.badge_name, opts.badge_label(active))
		state.tops = tops
		state.entries = entries
		state.files = files
		state.label = active
		local current = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
		state.context = { file = current, eidx = nil }
		self.paint_current()
		local found = false
		for _, f in ipairs(state.files) do
			if f.filename == current then
				found = true
				break
			end
		end
		if not found and #state.files > 0 then
			vim.notify(
				string.format(
					"Git review: no range hunks in this file — n/N jumps to %s",
					vim.fn.fnamemodify(state.files[1].filename, ":t")
				),
				vim.log.levels.INFO
			)
		end
		return true
	end

	function self.refresh()
		local target = self.target()
		if target == nil then
			return
		end
		local tops, entries, files = collect_entries(target)
		state.tops = tops
		state.entries = entries
		state.files = files
		state.label = target
		self.paint_current()
	end

	---@param entry table|nil { filename, lnum }
	---@return boolean
	local function goto_entry(entry)
		if entry == nil then
			return false
		end
		local lnum = entry.lnum and entry.lnum > 0 and entry.lnum or 1
		local abs = vim.fn.fnamemodify(entry.filename, ":p")
		local cur_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()), ":p")
		if cur_name ~= abs then
			local ok = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(entry.filename))
			if not ok then
				vim.notify("Git review: cannot open " .. entry.filename, vim.log.levels.WARN)
				return false
			end
		end
		pcall(vim.api.nvim_win_set_cursor, 0, { lnum, 0 })
		pcall(vim.cmd, "normal! zz")
		return true
	end

	---@param dir integer +1 next, -1 prev
	function self.entry_jump(dir)
		if not self.is_enabled() or Picker.is_open() then
			return
		end
		if #state.entries == 0 then
			self.refresh()
		end
		if #state.entries == 0 then
			vim.notify("Git review: no changes", vim.log.levels.INFO)
			return
		end
		local cur_buf = vim.api.nvim_get_current_buf()
		local cur = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(cur_buf), ":p")
		local owned = {}
		for i, entry in ipairs(state.entries) do
			if self.same_file(entry, cur_buf, cur) then
				owned[#owned + 1] = i
			end
		end
		if #owned == 0 then
			vim.notify("Git review: no diffs in this file", vim.log.levels.INFO)
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
			state.context = { file = cur, eidx = target_eidx }
			self.paint_current()
		end
	end

	-- Jump to the first range entry of `abs_path`.
	---@param abs_path string
	---@return integer|nil landed entries index
	local function jump_to_file(abs_path)
		for i, entry in ipairs(state.entries) do
			if self.same_file(entry, self.bufnr_for(abs_path), abs_path) then
				if goto_entry(entry) then
					return i
				end
				return nil
			end
		end
		return nil
	end

	function self.next_file()
		if not self.is_enabled() or Picker.is_open() then
			return
		end
		if #state.files == 0 then
			self.refresh()
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
			state.context = { file = target, eidx = landed }
			self.paint_current()
		end
	end

	function self.prev_file()
		if not self.is_enabled() or Picker.is_open() then
			return
		end
		if #state.files == 0 then
			self.refresh()
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
			state.context = { file = target, eidx = landed }
			self.paint_current()
		end
	end

	---@param on_cancel? fun() called when the picker closes without a selection
	---@param on_activated? fun() called after a target range is applied
	function self.open_picker(on_cancel, on_activated)
		Picker.close()
		hide_badge()
		range_hunks.clear_all()
		local previous = self.target()
		local tops = {}
		local ok_tops, res = pcall(review_files.repo_toplevels)
		if ok_tops and type(res) == "table" then
			tops = res
		end
		local cwd = tops[1] or vim.fn.getcwd()
		local ok_items, items = pcall(opts.list_targets, cwd)
		if not ok_items or type(items) ~= "table" or #items == 0 then
			vim.notify("Git review: no targets found", vim.log.levels.WARN)
			if on_cancel ~= nil then
				on_cancel()
			end
			return
		end
		local resolve = nil
		if opts.resolve_target ~= nil then
			resolve = function(query)
				local ok, item = pcall(opts.resolve_target, cwd, query)
				if ok then
					return item
				end
				return nil
			end
		end
		Picker.open({
			title = opts.picker_title,
			items = items,
			filter = opts.filter_target,
			resolve = resolve,
			empty_text = opts.picker_empty,
			on_select = function(value)
				if not self.activate(value) then
					if previous ~= nil then
						self.set_target(previous)
					else
						self.clear_target()
					end
					self.open_picker(on_cancel, on_activated)
					return
				end
				if on_activated ~= nil then
					on_activated()
				end
			end,
			on_cancel = function()
				if on_cancel ~= nil then
					on_cancel()
				end
			end,
		})
	end

	-- Test seam: reset module state between specs.
	function self._reset()
		self.disable()
		state.entries = {}
		state.files = {}
		state.tops = {}
		state.label = nil
		state.context = { file = nil, eidx = nil }
		Picker._reset()
	end

	return self
end

return M
