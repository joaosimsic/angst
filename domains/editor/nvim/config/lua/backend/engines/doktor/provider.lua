local AdapterScanner = require("backend.shared.AdapterScanner")

local M = {}

---@class DependencyProvider
---@field filetypes string[]
---@field query string
---@field lang? string|table<string, string>
---@field extract? fun(match: table<string, TSNode>, bufnr: integer): DependencyData

---@class ProviderRegistry
---@field private _by_ft table<string, DependencyProvider>
local ProviderRegistry = {}
ProviderRegistry.__index = ProviderRegistry

---@return ProviderRegistry
function M.new()
	return setmetatable({
		_by_ft = {},
	}, ProviderRegistry)
end

---@param provider DependencyProvider
function ProviderRegistry:register(provider)
	for _, filetype in ipairs(provider.filetypes or {}) do
		self._by_ft[filetype] = provider
	end
end

---@param filetype string
---@return DependencyProvider|nil
function ProviderRegistry:get(filetype)
	return self._by_ft[filetype]
end

---@param filetype string
---@param provider DependencyProvider
---@return string
local function language_for(filetype, provider)
	local lang_cfg = provider.lang --

	if type(lang_cfg) == "table" then
		---@type string|nil
		local lang = lang_cfg[filetype]
		return lang or filetype
	end

	if type(lang_cfg) == "string" then
		return lang_cfg
	end

	return filetype
end

---@param node TSNode|string|nil
---@param bufnr integer
---@return string|nil
local function node_text(node, bufnr)
	if type(node) ~= "userdata" then
		return nil
	end

	local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
	if not ok then
		return nil
	end

	return (text:gsub("^[\"']", ""):gsub("[\"']$", ""))
end

---@param match table
---@param query vim.treesitter.Query
---@return table<string, TSNode>
local function named_match(match, query)
	local named = {}

	for id, nodes in pairs(match) do
		local capture_name = query.captures[id]
		if #capture_name == 0 then
			goto continue
		end

		if type(nodes) == "table" then
			named[capture_name] = nodes[1]
		else
			named[capture_name] = nodes
		end

		::continue::
	end

	return named
end

---@param named table<string, TSNode>
---@param bufnr integer
---@return DependencyData
local function default_extract(named, bufnr)
	local data = {
		imports = {},
		exports = {},
		volatile = false,
	}

	local import_text = node_text(named.import, bufnr)
	if import_text and import_text ~= "" then
		data.imports[#data.imports + 1] = import_text
	end

	local export_text = node_text(named.export, bufnr)
	if export_text and export_text ~= "" then
		data.exports[#data.exports + 1] = export_text
	end

	if named.dynamic_import then
		data.volatile = true
	end

	return data
end

---@param bufnr integer
---@return DependencyData|nil
function ProviderRegistry:analyze(bufnr)
	local filetype = vim.bo[bufnr].filetype
	local provider = self:get(filetype)
	if not provider then
		return nil
	end

	local lang = language_for(filetype, provider)
	local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
	if not ok_parser or not parser then
		return nil
	end

	local ok_query, query = pcall(vim.treesitter.query.parse, lang, provider.query)
	if not ok_query or not query then
		return nil
	end

	local tree = parser:parse()[1]
	if not tree then
		return nil
	end

	---@type DependencyData
	local aggregate = {
		imports = {},
		exports = {},
		volatile = false,
	}

	local extract = provider.extract or function(match)
		return default_extract(match, bufnr)
	end

	for _, match in query:iter_matches(tree:root(), bufnr, 0, -1) do
		local data = extract(named_match(match, query), bufnr)
		for _, token in ipairs(data.imports or {}) do
			aggregate.imports[#aggregate.imports + 1] = token
		end
		for _, token in ipairs(data.exports or {}) do
			aggregate.exports[#aggregate.exports + 1] = token
		end
		aggregate.volatile = aggregate.volatile or data.volatile == true
	end

	return aggregate
end

---@return ProviderRegistry
function M.from_adapters()
	local registry = M.new()

	for _, adapter in pairs(AdapterScanner:adapters()) do
		if type(adapter) == "table" and adapter.doktor_provider then
			registry:register(adapter.doktor_provider)
		end
	end

	return registry
end

M.ProviderRegistry = ProviderRegistry

return M
