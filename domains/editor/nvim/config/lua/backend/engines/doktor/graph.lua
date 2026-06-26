local M = {}

---@class DependencyData
---@field imports string[]
---@field exports string[]
---@field volatile? boolean

---@class GraphNode
---@field path string
---@field filetype string
---@field imports string[]
---@field reverse_deps table<string, true>
---@field interface_hash string|nil
---@field dirty boolean
---@field volatile boolean
---@field mtime integer|nil

---@class Graph
---@field private _nodes table<string, GraphNode>
local Graph = {}
Graph.__index = Graph

---@param values string[]
---@return string
local function hash_values(values)
	local copy = vim.deepcopy(values or {})
	table.sort(copy)
	return vim.fn.sha256(table.concat(copy, "\n"))
end

---@param path string
---@return string
local function normalize_path(path)
	return vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path, ":p")
end

---@return Graph
function M.new()
	return setmetatable({
		_nodes = {},
	}, Graph)
end

---@param path string
---@return GraphNode|nil
function Graph:get(path)
	return self._nodes[normalize_path(path)]
end

---@return table<string, GraphNode>
function Graph:nodes()
	return self._nodes
end

---@param path string
---@param filetype string
---@return GraphNode
function Graph:upsert(path, filetype)
	local real_path = normalize_path(path)
	local node = self._nodes[real_path]

	if not node then
		node = {
			path = real_path,
			filetype = filetype,
			imports = {},
			reverse_deps = {},
			interface_hash = nil,
			dirty = true,
			volatile = false,
			mtime = nil,
		}
		self._nodes[real_path] = node
	else
		node.filetype = filetype
	end

	local stat = vim.uv.fs_stat(real_path)
	if stat and stat.mtime then
		node.mtime = stat.mtime.sec
	end

	return node
end

---@param path string
---@param imports string[]
local function clear_reverse_edges(self, path, imports)
	for _, imported_path in ipairs(imports or {}) do
		local imported = self._nodes[imported_path]
		if imported then
			imported.reverse_deps[path] = nil
		end
	end
end

---@param path string
---@param imports string[]
local function add_reverse_edges(self, path, imports)
	for _, imported_path in ipairs(imports or {}) do
		local imported = self._nodes[imported_path]
		if imported then
			imported.reverse_deps[path] = true
		end
	end
end

---@param path string
---@return string[]
function Graph:dependents_of(path)
	local node = self:get(path)
	if not node then
		return {}
	end

	local dependents = vim.tbl_keys(node.reverse_deps)
	table.sort(dependents)
	return dependents
end

---@param path string
---@return string[]
function Graph:transitive_dependents_of(path)
	local queue = self:dependents_of(path)
	local seen = {}
	local result = {}

	while #queue > 0 do
		local current = table.remove(queue, 1)

		if seen[current] then
			goto continue
		end

		seen[current] = true
		result[#result + 1] = current

		for _, dependent in ipairs(self:dependents_of(current)) do
			if not seen[dependent] then
				queue[#queue + 1] = dependent
			end
		end
		::continue::
	end

	return result
end

---@class GraphCascade
---@field source string
---@field direct string[]
---@field transitive string[]

---@param path string
---@param data DependencyData
---@return GraphCascade
function Graph:apply(path, data)
	local real_path = normalize_path(path)
	local node = self._nodes[real_path]

	if not node then
		node = self:upsert(real_path, vim.filetype.match({ filename = real_path }) or "")
	end

	local next_hash = hash_values(data.exports or {})
	local interface_changed = node.interface_hash ~= next_hash

	clear_reverse_edges(self, real_path, node.imports)
	node.imports = {}

	for _, imported_path in ipairs(data.imports or {}) do
		local real_import = normalize_path(imported_path)
		node.imports[#node.imports + 1] = real_import
		if not self._nodes[real_import] then
			self:upsert(real_import, vim.filetype.match({ filename = real_import }) or node.filetype)
		end
	end

	add_reverse_edges(self, real_path, node.imports)
	node.interface_hash = next_hash
	node.volatile = data.volatile == true
	node.dirty = false

	local result = {
		source = real_path,
		direct = {},
		transitive = {},
	}

	if not interface_changed and not node.volatile then
		return result
	end

	result.direct = self:dependents_of(real_path)
	local direct_set = {}
	for _, dependent in ipairs(result.direct) do
		direct_set[dependent] = true
	end

	for _, dependent in ipairs(self:transitive_dependents_of(real_path)) do
		if not direct_set[dependent] then
			result.transitive[#result.transitive + 1] = dependent
		end
	end

	return result
end

---@param nodes table<string, GraphNode>
function Graph:hydrate(nodes)
	self._nodes = nodes or {}
end

---@return table<string, GraphNode>
function Graph:serialize()
	return self._nodes
end

M.Graph = Graph

return M
