-- Background-only code overlay for branch-diff hunks.
--
-- Worktree mode tints the code buffer through gitsigns, but branch hunks
-- are committed (`base..HEAD`) with a clean worktree, so gitsigns paints
-- nothing. This module paints the same bg-only tints from branch entries
-- instead: added/changed lines take GitSignsAddLn/ChangeLn, deleted
-- hunks tint their anchor line DeleteLn (no virtual deleted lines, no
-- text recolor — same contract as the worktree mode). Only the current
-- code buffer is painted; the sidebar panes are untouched.
local M = {}

M.ns = vim.api.nvim_create_namespace("angst_git_branch_hunks")

local HL_BY_KIND = {
	A = "GitSignsAddLn",
	M = "GitSignsChangeLn",
	D = "GitSignsDeleteLn",
}

-- Parse a compact row ("112: (+21) A", "11: (~5) M", "4: (-1) D").
---@param text string
---@return integer? lnum, integer? n, string? kind
local function parse_row(text)
	if type(text) ~= "string" then
		return nil
	end
	local lnum, _sign, n, kind = text:match("^(%d+): %((.)(%d+)%) (%S+)$")
	if lnum == nil then
		return nil
	end
	return tonumber(lnum), tonumber(n), kind
end

---@return boolean
local function hunks_enabled()
	local ok, display = pcall(require, "frontend.tools.git_hunk_display")
	if not ok or type(display) ~= "table" or type(display.is_enabled) ~= "function" then
		return true
	end
	local ok_enabled, on = pcall(display.is_enabled)
	if not ok_enabled then
		return true
	end
	return on
end

---@param bufnr integer
function M.clear(bufnr)
	if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
		pcall(vim.api.nvim_buf_clear_namespace, bufnr, M.ns, 0, -1)
	end
end

function M.clear_all()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			pcall(vim.api.nvim_buf_clear_namespace, bufnr, M.ns, 0, -1)
		end
	end
end

-- Paint branch hunks for one buffer. `hunks` are { lnum, text } rows
-- already filtered to the buffer's file.
---@param bufnr integer
---@param hunks table[]
function M.paint(bufnr, hunks)
	M.clear(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	if not hunks_enabled() then
		return
	end
	if type(hunks) ~= "table" or #hunks == 0 then
		return
	end
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	for _, h in ipairs(hunks) do
		local lnum, n, kind = parse_row(h.text)
		if lnum ~= nil and HL_BY_KIND[kind] ~= nil then
			-- Landing-side range: N added lines from lnum; deleted
			-- hunks land nowhere, so tint the anchor line only.
			local from = math.max(1, math.min(lnum, line_count))
			local to = kind == "D" and from or math.max(from, math.min(lnum + (n or 1) - 1, line_count))
			for row = from, to do
				pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns, row - 1, 0, {
					line_hl_group = HL_BY_KIND[kind],
					priority = 100,
					strict = false,
				})
			end
		end
	end
end

return M
