---@type Logger
local logger = require("frontend.navigation.doktor.logger")

local M = {}

---@type DoktorConfig
local DEFAULTS = {
	auto_start = true,
	namespace_name = "doktor-workspace",
	debounce_ms = 200,
	adapter_overrides = {},
	window = {
		width_ratio = 0.8,
		height_ratio = 0.6,
		border = "rounded",
	},
}

---@type DoktorConfig
local current_config = vim.deepcopy(DEFAULTS)

---@param base table
---@param override table
---@return table
local function deep_merge(base, override)
	---@type table
	local result = vim.deepcopy(base)
	for k, v in pairs(override) do
		if type(v) == "table" and type(result[k]) == "table" and not vim.islist(v) then
			result[k] = deep_merge(result[k], v)
		else
			result[k] = vim.deepcopy(v)
		end
	end
	return result
end

---@param opts? table
---@return DoktorConfig
function M.setup(opts)
	if opts then
		current_config = deep_merge(DEFAULTS, opts)
		logger:debug(function()
			---@type string[]
			local keys = {}
			for k in pairs(opts) do
				table.insert(keys, k)
			end
			return string.format("Config merged with overrides: %s", table.concat(keys, ", "))
		end)
	else
		current_config = vim.deepcopy(DEFAULTS)
	end

	logger:info(function()
		return "Doktor configured"
	end)

	return current_config
end

---@return DoktorConfig
function M.get()
	return current_config
end

return M
