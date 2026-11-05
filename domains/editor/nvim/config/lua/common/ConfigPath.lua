local M = {}

local function uv()
	return vim.uv or vim.loop
end

local function is_under(path, root)
	return path == root or path:sub(1, #root + 1) == root .. "/"
end

local function config_dirs()
	local dir = vim.fs.normalize(vim.fn.stdpath("config"))
	local real = uv().fs_realpath(dir) or dir
	return dir, real
end

---@param path string
---@return boolean
function M.is_config_path(path)
	if type(path) ~= "string" or path == "" then
		return false
	end

	local config_dir, config_real = config_dirs()
	local normalized = vim.fs.normalize(path)
	local real = uv().fs_realpath(normalized) or normalized

	return is_under(normalized, config_dir) or is_under(real, config_real)
end

---@param paths string[]
---@return string[]
function M.filter(paths)
	local config_dir, config_real = config_dirs()
	local filtered = {}
	local seen = {}

	for _, path in ipairs(paths) do
		local normalized = vim.fs.normalize(path)
		local real = uv().fs_realpath(normalized) or normalized

		if not is_under(normalized, config_dir) and not is_under(real, config_real) and not seen[real] then
			seen[real] = true
			filtered[#filtered + 1] = path
		end
	end

	return filtered
end

return M
