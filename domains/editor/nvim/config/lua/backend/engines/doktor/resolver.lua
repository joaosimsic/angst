local AdapterScanner = require("backend.shared.AdapterScanner")

local M = {}

---@class PathResolver
---@field filetypes string[]
---@field resolve fun(token: string, context_buf: integer): string|nil

---@class ResolverRegistry
---@field private _by_ft table<string, PathResolver>
local ResolverRegistry = {}
ResolverRegistry.__index = ResolverRegistry

---@return ResolverRegistry
function M.new()
	return setmetatable({
		_by_ft = {},
	}, ResolverRegistry)
end

---@param resolver PathResolver
function ResolverRegistry:register(resolver)
	for _, filetype in ipairs(resolver.filetypes or {}) do
		self._by_ft[filetype] = resolver
	end
end

---@param filetype string
---@return PathResolver|nil
function ResolverRegistry:get(filetype)
	return self._by_ft[filetype]
end

---@param path string
---@return string|nil
local function existing_file(path)
	local stat = vim.uv.fs_stat(path)
	if stat and stat.type == "file" then
		return vim.uv.fs_realpath(path) or path
	end
end

---@param token string
---@param context_buf integer
---@return string|nil
local function default_resolve(token, context_buf)
	if token == "" then
		return nil
	end

	local current_path = vim.api.nvim_buf_get_name(context_buf)
	local current_dir = vim.fn.fnamemodify(current_path, ":h")

	if token:sub(1, 1) == "." then
		local candidate = vim.fs.normalize(current_dir .. "/" .. token)
		return existing_file(candidate)
	end

	return nil
end

---@param token string
---@param context_buf integer
---@return string|nil
function ResolverRegistry:resolve(token, context_buf)
	local filetype = vim.bo[context_buf].filetype
	local resolver = self:get(filetype)
	if resolver then
		local ok, resolved = pcall(resolver.resolve, token, context_buf)
		if ok and resolved then
			return vim.uv.fs_realpath(resolved) or resolved
		end
	end

	return default_resolve(token, context_buf)
end

---@param data DependencyData
---@param context_buf integer
---@return DependencyData
function ResolverRegistry:resolve_data(data, context_buf)
	local resolved = {
		imports = {},
		exports = data.exports or {},
		volatile = data.volatile == true,
	}

	for _, token in ipairs(data.imports or {}) do
		local path = self:resolve(token, context_buf)
		if path then
			resolved.imports[#resolved.imports + 1] = path
		else
			resolved.volatile = true
		end
	end

	return resolved
end

---@return ResolverRegistry
function M.from_adapters()
	local registry = M.new()

	for _, adapter in pairs(AdapterScanner:adapters()) do
		if type(adapter) == "table" and adapter.doktor_resolver then
			registry:register(adapter.doktor_resolver)
		end
	end

	return registry
end

M.ResolverRegistry = ResolverRegistry

return M
