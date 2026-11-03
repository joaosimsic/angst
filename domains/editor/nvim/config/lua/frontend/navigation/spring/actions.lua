local Badge = require("common.Badge")
local palette = require("config.theme.palette")
local state = require("frontend.navigation.spring.state")

local MAX_BADGE_SEGMENTS = 5

local M = {}

---@type Badge|nil
local badge = nil

local function format_chain()
	local chain = vim.tbl_filter(function(label)
		return label ~= nil and label ~= ""
	end, state.chain())

	if #chain == 0 then
		return nil
	end

	if #chain <= MAX_BADGE_SEGMENTS then
		return table.concat(chain, " > ")
	end

	local segments = { chain[1], "…" }
	local first_visible_index = #chain - (MAX_BADGE_SEGMENTS - 2) + 1

	for i = first_visible_index, #chain do
		segments[#segments + 1] = chain[i]
	end

	return table.concat(segments, " > ")
end

local function refresh_badge()
	if not badge then
		return
	end

	if not state.is_active() then
		badge:hide("spring")
		return
	end

	local chain_text = format_chain()

	if chain_text then
		badge:show("spring", chain_text)
	else
		badge:hide("spring")
	end
end

---@param snapshot table
---@return number|nil
local function resolve_origin_buffer(snapshot)
	if snapshot.bufnr and vim.api.nvim_buf_is_valid(snapshot.bufnr) then
		return snapshot.bufnr
	end

	if not snapshot.filename or snapshot.filename == "" or vim.fn.filereadable(snapshot.filename) ~= 1 then
		return nil
	end

	local bufnr = vim.fn.bufadd(snapshot.filename)
	vim.fn.bufload(bufnr)

	if vim.api.nvim_buf_is_valid(bufnr) then
		return bufnr
	end

	return nil
end

---@param bufnr number
---@param line number
---@param col number
---@return number
local function clamp_col(bufnr, line, col)
	local text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ""
	return math.max(0, math.min(col, #text))
end

---@param snapshot table
---@return boolean
local function restore_origin(snapshot)
	local restored = pcall(function()
		if snapshot.tabpage and vim.api.nvim_tabpage_is_valid(snapshot.tabpage) then
			vim.api.nvim_set_current_tabpage(snapshot.tabpage)
		end

		local bufnr = resolve_origin_buffer(snapshot)

		if not bufnr then
			error("origin buffer is gone")
		end

		local winid = snapshot.winid

		if winid and vim.api.nvim_win_is_valid(winid) then
			vim.api.nvim_set_current_win(winid)
		else
			winid = vim.api.nvim_get_current_win()
		end

		if vim.api.nvim_win_get_buf(winid) ~= bufnr then
			vim.api.nvim_win_set_buf(winid, bufnr)
		end

		local line = math.max(1, math.min(snapshot.line or 1, vim.api.nvim_buf_line_count(bufnr)))
		local col = clamp_col(bufnr, line, snapshot.col or 0)

		vim.api.nvim_win_set_cursor(winid, { line, col })
		vim.cmd("normal! zz")
	end)

	return restored
end

function M.toggle()
	if state.is_active() then
		local snapshot = state.release()
		local restored = snapshot ~= nil and restore_origin(snapshot)
		refresh_badge()

		if not restored then
			vim.notify("Spring: could not restore origin", vim.log.levels.WARN)
		end

		return
	end

	state.pull(state.capture())
	refresh_badge()
end

---@param logger Logger|nil
function M.setup(logger)
	local group = vim.api.nvim_create_augroup("SpringTracker", { clear = true })

	badge = Badge.new({
		name = "spring",
		prefix = "",
		align = "left",
		fg = palette.p.background.base,
		bg = palette.p.surface.base,
	})

	if logger then
		logger:debug("Spring ready")
	end

	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function(event)
			if not state.is_active() then
				return
			end

			if state.record_visit(event.buf) then
				refresh_badge()
			end
		end,
	})
end

return M
