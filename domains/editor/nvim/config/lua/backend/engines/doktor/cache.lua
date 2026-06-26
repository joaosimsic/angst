local graph_mod = require("backend.engines.doktor.graph")

local M = {}

local SCHEMA_VERSION = 1

---@param path string
local function ensure_parent(path)
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
end

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

	pcall(vim.fn.writefile, { encoded }, config.cache_path)
end

---@param config DoktorConfig
---@return Graph|nil
function M.load(config)
	if vim.fn.filereadable(config.cache_path) ~= 1 then
		return nil
	end

	local ok_read, lines = pcall(vim.fn.readfile, config.cache_path)
	if not ok_read or not lines[1] then
		return nil
	end

	local ok_decode, payload = pcall(vim.json.decode, table.concat(lines, "\n"))
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
