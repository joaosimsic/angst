local Path = require("plenary.path")

local M = {}

---@param path string
---@return string
function M.normalize(path)
	local p = Path:new(path)
	return p:absolute() or vim.fn.fnamemodify(path, ":p")
end

---@param path string
---@return string|nil
function M.existing_file(path)
	local p = Path:new(path)
	if p:exists() and p:is_file() then
		return p:absolute() or path
	end
end

---@param path string
---@return string
function M.realpath(path)
	local p = Path:new(path)
	return p:absolute() or path
end

---@param path string
---@return integer|nil
function M.mtime_sec(path)
	local stat = Path:new(path):_stat()
	return stat and stat.mtime and stat.mtime.sec
end

return M
