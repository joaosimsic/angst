local Logger = require("common.Logger")

local logger = Logger.new("ADAPTER")

local M = {}

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

---@param module_path string
---@return any
local function require_module(module_path)
	local ok, result = pcall(require, module_path)

	if ok then
		return result
	end

	logger:error(function()
		return "Failed loading adapter module '" .. module_path .. "': " .. tostring(result)
	end)
end

---@param module_name string
---@return { name: string, module: string }[]
local function adapter_modules(module_name)
	local modules = {}
	local seen = {}
	local root = module_dir(module_name)

	local files = vim.fn.glob(root .. "/*.lua", false, true)
	table.sort(files)

	for _, file in ipairs(files) do
		local name = vim.fn.fnamemodify(file, ":t:r")

		if name ~= "init" then
			modules[#modules + 1] = {
				name = name,
				module = module_name .. "." .. name,
			}
			seen[name] = true
		end
	end

	local dirs = vim.fn.glob(root .. "/*/init.lua", false, true)
	table.sort(dirs)

	for _, file in ipairs(dirs) do
		local dir = vim.fn.fnamemodify(file, ":h")
		local name = vim.fn.fnamemodify(dir, ":t")

		if not seen[name] then
			modules[#modules + 1] = {
				name = name,
				module = module_name .. "." .. name,
			}
			seen[name] = true
		end
	end

	return modules
end

---@param module_name string
---@return table<string, Adapter>
function M.load(module_name)
	local adapters = {}

	for _, adapter_module in ipairs(adapter_modules(module_name)) do
		local adapter = require_module(adapter_module.module)

		if type(adapter) == "table" then
			adapters[adapter_module.name] = adapter
		end
	end

	return adapters
end

---@param module_name string
---@return string[]
function M.plugin_modules(module_name)
	local modules = {}
	local root = module_dir(module_name)
	local files = vim.fn.glob(root .. "/*/plugins.lua", false, true)
	table.sort(files)

	for _, file in ipairs(files) do
		local dir = vim.fn.fnamemodify(file, ":h")
		local name = vim.fn.fnamemodify(dir, ":t")

		modules[#modules + 1] = module_name .. "." .. name .. ".plugins"
	end

	return modules
end

return M
