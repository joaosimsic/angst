local Logger = require("common.Logger")
local Spec = require("common.Spec")
local logger = Logger.new("ADAPTER")

local M = {}

---@alias LspCmd string[]|fun():string[]|nil

---@class AdapterLspInfo
---@field cmd LspCmd
---@field settings table|nil
---@field filetypes string[]|nil

---@class EngineOpts
---@field check_executable? boolean

local adapters_cache
local executable_cache = {}
local plugin_specs_cache

local function resolve_cmd(cmd)
	if type(cmd) == "function" then
		return cmd()
	end
	return cmd
end

local function get_adapters()
	if adapters_cache then
		return adapters_cache
	end

	local ok, adapters = pcall(require, "backend.adapters")

	if not ok then
		logger:error(function()
			return "Failed to require 'backend.adapters': " .. tostring(adapters)
		end)

		return {}
	end

	if type(adapters) ~= "table" then
		logger:warn(function()
			return "'backend.adapters' did not return a table module"
		end)

		return {}
	end

	adapters_cache = adapters
	return adapters
end

local function executable_exists(name)
	if executable_cache[name] ~= nil then
		return executable_cache[name]
	end

	local exists = vim.fn.executable(name) == 1
	executable_cache[name] = exists

	return exists
end

---@param engine_name string
---@param opts? EngineOpts
---@return table<string, AdapterLspInfo>
local function scan_engine_tools(engine_name, opts)
	local active_tools = {}

	opts = opts or {}

	local check_executable = opts.check_executable ~= false
	local cmd_field = engine_name .. "_cmd"

	for _, adapter in pairs(get_adapters()) do
		if type(adapter) ~= "table" then
			goto continue
		end

		local tool_name = adapter[engine_name]

		if type(tool_name) ~= "string" then
			goto continue
		end

		if check_executable then
			local raw_cmd = adapter[cmd_field]
			local resolved_cmd = resolve_cmd(raw_cmd)
			local executable_name =
				type(resolved_cmd) == "table" and resolved_cmd[1]
				or type(raw_cmd) ~= "function" and tool_name

			if executable_name and not executable_exists(executable_name) then
				logger:warn(function()
					return "Tool '" .. tool_name
						.. "' found but binary '"
						.. executable_name
						.. "' is unavailable."
				end)

				goto continue
			end

			if resolved_cmd == nil then
				goto continue
			end
		end

		active_tools[tool_name] = {
			cmd = adapter[cmd_field],
			settings = adapter.lsp_settings
				and adapter.lsp_settings[tool_name]
				or nil,
			filetypes = adapter.filetypes,
		}

		::continue::
	end

	return active_tools
end

local function find_plugin_files(path)
	local files = {}

	local ok, entries = pcall(vim.fn.readdir, path)

	if not ok then
		return files
	end

	for _, name in ipairs(entries) do
		local file = path .. "/" .. name .. "/plugins.lua"

		if vim.fn.filereadable(file) == 1 then
			files[#files + 1] = file
		end
	end

	return files
end

function M.scan_plugins()
	if plugin_specs_cache then
		return plugin_specs_cache
	end

	local specs = {}
	local adapters_path = vim.fn.stdpath("config")
		.. "/lua/backend/adapters"

	for _, file in ipairs(find_plugin_files(adapters_path)) do
		local lang_name = vim.fn.fnamemodify(file, ":h:t")
		local module_path = "backend.adapters." .. lang_name .. ".plugins"

		local ok, plugin_spec = pcall(require, module_path)

		if not ok or type(plugin_spec) ~= "table" then
			logger:error(function()
				return "Failed loading plugin spec: " .. module_path
			end)

			goto continue
		end

		Spec.collect(plugin_spec, specs)

		::continue::
	end

	plugin_specs_cache = specs

	return specs
end

return setmetatable(M, {
	__call = function(_, engine_name, opts)
		return scan_engine_tools(engine_name, opts)
	end,
})
