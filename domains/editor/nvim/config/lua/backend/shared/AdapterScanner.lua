local Logger = require("common.Logger")
local AdapterTool = require("backend.shared.AdapterTool")

local logger = Logger.new("ADAPTER")

---@class AdapterScannerOpts
---@field check_executable? boolean

---@class AdapterScanner
---@field adapter_module string
---@field adapters_cache table<string, Adapter>|nil
---@field executable_cache table<string, boolean>
---@field tool_cache table<string, table<string, AdapterToolInfo>>
---@field filetype_cache table<string, table<string, string[]>>
local AdapterScanner = {}
AdapterScanner.__index = AdapterScanner

---@param adapter_module? string
---@return AdapterScanner
function AdapterScanner.new(adapter_module)
	return setmetatable({
		adapter_module = adapter_module or "backend.adapters",
		adapters_cache = nil,
		executable_cache = {},
		tool_cache = {},
		filetype_cache = {},
	}, AdapterScanner)
end

---@param opts? AdapterScannerOpts
---@return boolean
local function should_check_executable(opts)
	return not opts or opts.check_executable ~= false
end

---@param engine_name string
---@param opts? AdapterScannerOpts
---@return string
local function cache_key(engine_name, opts)
	return engine_name .. ":" .. tostring(should_check_executable(opts))
end

---@return table<string, Adapter>
function AdapterScanner:adapters()
	if self.adapters_cache then
		return self.adapters_cache
	end

	local ok, adapters = pcall(require, self.adapter_module)

	if not ok then
		logger:error(function()
			return "Failed to require '" .. self.adapter_module .. "': " .. tostring(adapters)
		end)

		return {}
	end

	if type(adapters) ~= "table" then
		logger:warn(function()
			return "'" .. self.adapter_module .. "' did not return a table module"
		end)

		return {}
	end

	self.adapters_cache = adapters
	return adapters
end

---@param name string
---@return boolean
function AdapterScanner:executable_exists(name)
	if self.executable_cache[name] ~= nil then
		return self.executable_cache[name]
	end

	local exists = vim.fn.executable(name) == 1
	self.executable_cache[name] = exists

	return exists
end

---@param engine_name string
---@param opts? AdapterScannerOpts
---@return table<string, AdapterToolInfo>
function AdapterScanner:by_tool(engine_name, opts)
	local key = cache_key(engine_name, opts)

	if self.tool_cache[key] then
		return self.tool_cache[key]
	end

	local tools = {}
	local check_executable = should_check_executable(opts)

	for _, adapter in pairs(self:adapters()) do
		if type(adapter) ~= "table" then
			goto continue
		end

		local tool_names = AdapterTool.names(adapter, engine_name)
		if not tool_names then
			goto continue
		end

		for _, tool_name in ipairs(tool_names) do
			if check_executable then
				local executable = AdapterTool.executable(adapter, engine_name, tool_name)

				if not executable then
					goto next_tool
				end

				if not self:executable_exists(executable) then
					logger:warn(function()
						return engine_name
							.. " '"
							.. tool_name
							.. "' found but binary '"
							.. tostring(executable)
							.. "' is unavailable."
					end)

					goto next_tool
				end
			end

			tools[tool_name] = AdapterTool.info(adapter, engine_name, tool_name)

			::next_tool::
		end

		::continue::
	end

	self.tool_cache[key] = tools
	return tools
end

---@param engine_name string
---@param opts? AdapterScannerOpts
---@return table<string, string[]>
function AdapterScanner:by_filetype(engine_name, opts)
	local key = cache_key(engine_name, opts)

	if self.filetype_cache[key] then
		return self.filetype_cache[key]
	end

	local tools_by_filetype = {}

	for tool_name, tool_opts in pairs(self:by_tool(engine_name, opts)) do
		for _, filetype in ipairs(tool_opts.filetypes or {}) do
			tools_by_filetype[filetype] = tools_by_filetype[filetype] or {}
			table.insert(tools_by_filetype[filetype], tool_name)
		end
	end

	for _, tool_names in pairs(tools_by_filetype) do
		table.sort(tool_names)
	end

	self.filetype_cache[key] = tools_by_filetype
	return tools_by_filetype
end

---@param engine_name string
---@param filetype string|nil
---@param opts? AdapterScannerOpts
---@return string[]
function AdapterScanner:tools_for_filetype(engine_name, filetype, opts)
	if not filetype or filetype == "" then
		return {}
	end

	return self:by_filetype(engine_name, opts)[filetype] or {}
end

---@param engine_name string
---@param filetype string|nil
---@param opts? AdapterScannerOpts
---@return boolean
function AdapterScanner:supports_filetype(engine_name, filetype, opts)
	return #self:tools_for_filetype(engine_name, filetype, opts) > 0
end

---@param engine_name string
---@param opts? AdapterScannerOpts
---@return string[]
function AdapterScanner:supported_filetypes(engine_name, opts)
	local filetypes = vim.tbl_keys(self:by_filetype(engine_name, opts))
	table.sort(filetypes)

	return filetypes
end

local default_scanner = AdapterScanner.new("backend.adapters")
default_scanner.new = AdapterScanner.new

return default_scanner
