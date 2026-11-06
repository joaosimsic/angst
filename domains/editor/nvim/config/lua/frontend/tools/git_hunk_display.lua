-- Single switch for all Git hunk display (background-only).
--
-- One global var drives every hunk surface: deleted-line overlay,
-- full-line background via linehl, and the floating hunk preview on jumps.
-- Word diff is never enabled: it recolors code text, this module keeps
-- hunks to background tints only. Signs in the signcolumn stay always on.
-- The switch persists across Neovim restarts in the state directory.
local M = {}

M.GLOBAL_VAR = "angst_git_hunks_enabled"
M.STATE_FILE_VAR = "angst_git_hunks_state_file"

local loaded = false

local function state_file()
	if vim.g[M.STATE_FILE_VAR] ~= nil then
		return vim.g[M.STATE_FILE_VAR]
	end
	return vim.fn.stdpath("state") .. "/angst/git-hunks.json"
end

local function load_state()
	if loaded then
		return
	end
	loaded = true
	local path = state_file()
	if vim.fn.filereadable(path) == 0 then
		return
	end
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok or type(lines) ~= "table" or #lines == 0 then
		return
	end
	local decoded_ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not decoded_ok or type(data) ~= "table" or type(data.enabled) ~= "boolean" then
		return
	end
	if vim.g[M.GLOBAL_VAR] == nil then
		vim.g[M.GLOBAL_VAR] = data.enabled
	end
end

local function save_state(on)
	local path = state_file()
	pcall(vim.fn.mkdir, vim.fn.fnamemodify(path, ":h"), "p")
	local ok, encoded = pcall(vim.json.encode, { enabled = on })
	if ok then
		pcall(vim.fn.writefile, { encoded }, path)
	end
end

local function gs()
	local ok, gitsigns = pcall(require, "gitsigns")
	if not ok then
		return nil
	end
	return gitsigns
end

---@return boolean
function M.is_enabled()
	load_state()
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
	loaded = true
	vim.g[M.GLOBAL_VAR] = on and true or false
	save_state(on and true or false)
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
