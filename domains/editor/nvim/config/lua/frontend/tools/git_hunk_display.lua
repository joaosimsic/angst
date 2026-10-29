-- Single switch for all Git hunk display (background-only).
--
-- One global var drives every hunk surface: deleted-line overlay,
-- full-line background via linehl, and the floating hunk preview on jumps.
-- Word diff is never enabled: it recolors code text, this module keeps
-- hunks to background tints only. Signs in the signcolumn stay always on.
local M = {}

M.GLOBAL_VAR = "angst_git_hunks_enabled"

local function gs()
	local ok, gitsigns = pcall(require, "gitsigns")
	if not ok then
		return nil
	end
	return gitsigns
end

---@return boolean
function M.is_enabled()
	if vim.g[M.GLOBAL_VAR] == nil then
		vim.g[M.GLOBAL_VAR] = true
	end
	return vim.g[M.GLOBAL_VAR] == true
end

-- Re-assert current state against gitsigns. Quiet: no notify.
function M.apply()
	local on = M.is_enabled()
	local g = gs()
	if not g then
		return on
	end
	pcall(g.toggle_deleted, on)
	pcall(g.toggle_linehl, on)
	-- Bg-only: word highlights recolor code text, keep them off always.
	pcall(g.toggle_word_diff, false)
	return on
end

---@param on boolean
function M.set(on)
	vim.g[M.GLOBAL_VAR] = on and true or false
	return M.apply()
end

---@return boolean new state
function M.toggle()
	local on = not M.is_enabled()
	M.set(on)
	vim.notify("Git hunks " .. (on and "on" or "off"), vim.log.levels.INFO)
	return on
end

return M
