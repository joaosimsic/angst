local Logger = require("common.Logger")

local logger = Logger.new("PLUGIN")

local M = {}

---@param values? string[]
---@return table<string, boolean>
local function as_set(values)
	local set = {}

	for _, value in ipairs(values or {}) do
		set[value] = true
	end

	return set
end

---@param module_name string
---@return string
local function module_dir(module_name)
	local module_path = module_name:gsub("%.", "/")
	local matches = vim.api.nvim_get_runtime_file("lua/" .. module_path .. "/init.lua", false)

	if matches[1] then
		return vim.fn.fnamemodify(matches[1], ":h")
	end

	return vim.fn.stdpath("config") .. "/lua/" .. module_path
end

---@param root string
---@param module_name string
---@param exclude table<string, boolean>
---@return string[]
local function collect_child_modules(root, module_name, exclude)
	local modules = {}

	local files = vim.fn.glob(root .. "/*.lua", false, true)
	table.sort(files)

	for _, file in ipairs(files) do
		local name = vim.fn.fnamemodify(file, ":t:r")

		if name ~= "init" and not exclude[name] then
			modules[#modules + 1] = module_name .. "." .. name
		end
	end

	local dirs = vim.fn.glob(root .. "/*/init.lua", false, true)
	table.sort(dirs)

	for _, file in ipairs(dirs) do
		local dir = vim.fn.fnamemodify(file, ":h")
		local name = vim.fn.fnamemodify(dir, ":t")

		if not exclude[name] then
			modules[#modules + 1] = module_name .. "." .. name
		end
	end

	return modules
end

---@param module_path string
---@return any
local function require_module(module_path)
	local ok, result = pcall(require, module_path)

	if ok then
		return result
	end

	logger:error(function()
		return "Failed loading plugin module '" .. module_path .. "': " .. tostring(result)
	end)
end

---@param value any
---@return boolean
function M.is_spec(value)
	return type(value) == "table" and (type(value[1]) == "string" or type(value.dir) == "string")
end

---@param source any
---@param target? table
---@return table
function M.collect(source, target)
	target = target or {}

	if type(source) ~= "table" then
		return target
	end

	if M.is_spec(source) then
		target[#target + 1] = source
		return target
	end

	if type(source.spec) == "table" then
		M.collect(source.spec, target)
	end

	for _, spec in ipairs(source) do
		M.collect(spec, target)
	end

	return target
end

---@class PluginLoaderOpts
---@field exclude? string[]
---@field adapter_plugins? string|string[]

---@param module_name string
---@param opts? PluginLoaderOpts
---@return table
function M.load(module_name, opts)
	opts = opts or {}

	local specs = {}
	local exclude = as_set(opts.exclude)
	local modules = collect_child_modules(module_dir(module_name), module_name, exclude)

	for _, module_path in ipairs(modules) do
		M.collect(require_module(module_path), specs)
	end

	local adapter_plugins = opts.adapter_plugins

	if type(adapter_plugins) == "string" then
		M.collect(M.load_adapter_plugins(adapter_plugins), specs)
	elseif type(adapter_plugins) == "table" then
		for _, adapter_module in ipairs(adapter_plugins) do
			M.collect(M.load_adapter_plugins(adapter_module), specs)
		end
	end

	return specs
end

---@param module_name string
---@return table
function M.load_adapter_plugins(module_name)
	local AdapterLoader = require("backend.shared.AdapterLoader")
	local specs = {}

	for _, module_path in ipairs(AdapterLoader.plugin_modules(module_name)) do
		local plugin_spec = require_module(module_path)

		if type(plugin_spec) ~= "table" then
			logger:error(function()
				return "Plugin module '" .. module_path .. "' did not return a table"
			end)
		else
			M.collect(plugin_spec, specs)
		end
	end

	return specs
end

return M
