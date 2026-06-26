local a = require("plenary.async")
local uv = a.uv
local graph_mod = require("backend.engines.doktor.graph")

local M = {}

local SCHEMA_VERSION = 1

---@param path string
local function ensure_parent(path)
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
end

---@async
---@param graph Graph
---@param config DoktorConfig
function M.save(graph, config)
	ensure_parent(config.cache_path)

	local payload = {
		version = SCHEMA_VERSION,
		workspace_hash = require("backend.engines.doktor.config").workspace_hash(),
		nodes = graph:serialize(),
	}

	local ok, encoded = pcall(vim.json.encode, payload)
	if not ok then
		return
	end

	a.util.scheduler()

	local fd = uv.fs_open(config.cache_path, "w", 438)
	if not fd then
		return
	end

	uv.fs_write(fd, encoded)
	uv.fs_close(fd)
end

---@async
---@param config DoktorConfig
---@return Graph|nil
function M.load(config)
	a.util.scheduler()

	if vim.fn.filereadable(config.cache_path) ~= 1 then
		return nil
	end

	local fd = uv.fs_open(config.cache_path, "r", 438)
	if not fd then
		return nil
	end

	local stat = uv.fs_fstat(fd)
	if not stat then
		uv.fs_close(fd)
		return nil
	end

	local data = uv.fs_read(fd, stat.size)
	uv.fs_close(fd)
	if not data then
		return nil
	end

	local ok_decode, payload = pcall(vim.json.decode, data)
	if not ok_decode or type(payload) ~= "table" then
		return nil
	end

	if payload.version ~= SCHEMA_VERSION then
		return nil
	end

	local graph = graph_mod.new()
	graph:hydrate(payload.nodes or {})
	return graph
end

return M
