local M = {}

---@type table|nil
local origin = nil

---@type string[]
local chain = {}

---@type string[]
local chain_files = {}

---@type string|nil
local last_filename = nil

local function filename_label(name)
	if not name or name == "" then
		return "[No Name]"
	end

	local label = vim.fn.fnamemodify(name, ":t")
	return label ~= "" and label or name
end

---@param name string|nil
---@return string
local function normalize_filename(name)
	if not name or name == "" then
		return ""
	end

	local absolute = vim.fn.fnamemodify(name, ":p")
	local fs = vim.uv or vim.loop
	local real = fs.fs_realpath(absolute)
	return real or absolute
end

---@return boolean
function M.is_active()
	return origin ~= nil
end

---@return table|nil
function M.origin()
	return origin
end

---@return string[]
function M.chain()
	return vim.deepcopy(chain)
end

---@return table
function M.capture()
	local winid = vim.api.nvim_get_current_win()
	local bufnr = vim.api.nvim_win_get_buf(winid)
	local cursor = vim.api.nvim_win_get_cursor(winid)
	local filename = vim.api.nvim_buf_get_name(bufnr)

	return {
		bufnr = bufnr,
		winid = winid,
		tabpage = vim.api.nvim_get_current_tabpage(),
		filename = filename,
		label = filename_label(filename),
		line = cursor[1],
		col = cursor[2],
	}
end

---@param snapshot table|nil
---@return boolean
function M.pull(snapshot)
	if not snapshot then
		return false
	end

	origin = snapshot
	local filename = normalize_filename(snapshot.filename)
	last_filename = filename
	chain = { snapshot.label or filename_label(snapshot.filename) }
	chain_files = { filename }
	return true
end

---@param snapshot table|nil
---@return boolean
function M.pull_if_inactive(snapshot)
	if origin then
		return false
	end

	return M.pull(snapshot)
end

---@return table|nil
function M.release()
	local snapshot = origin
	origin = nil
	chain = {}
	chain_files = {}
	last_filename = nil
	return snapshot
end

---@param bufnr number|nil
---@return boolean
function M.record_visit(bufnr)
	if not origin then
		return false
	end

	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if vim.bo[bufnr].buftype ~= "" then
		return false
	end

	local raw_filename = vim.api.nvim_buf_get_name(bufnr)
	local filename = normalize_filename(raw_filename)

	if filename == "" or filename == last_filename then
		return false
	end

	for _, known in ipairs(chain_files) do
		if known == filename then
			return false
		end
	end

	chain[#chain + 1] = filename_label(raw_filename)
	chain_files[#chain_files + 1] = filename
	last_filename = filename
	return true
end

function M.reset()
	origin = nil
	chain = {}
	chain_files = {}
	last_filename = nil
end

return M
