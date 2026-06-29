local M = {}

---@alias DoktorPriority 0|1|2|3
---@alias DoktorConcurrency integer|"auto"

---@class DoktorPoolConfig
---@field lsp DoktorConcurrency
---@field lint DoktorConcurrency

---@class DoktorBootstrapConfig
---@field on_vim_enter boolean
---@field max_files_per_tick integer

---@class DoktorWindowConfig
---@field width_ratio number
---@field height_ratio number
---@field border string|string[]

---@class DoktorConfig
---@field concurrency DoktorPoolConfig
---@field bootstrap DoktorBootstrapConfig
---@field debounce_ms integer
---@field idle_ms integer
---@field max_hidden_buffers integer
---@field cache_path string
---@field notify_on_error boolean
---@field log_level "debug"|"info"|"warn"|"error"
---@field lsp_timeout_ms integer
---@field window DoktorWindowConfig

---@type DoktorConfig
local DEFAULTS = {
	concurrency = {
		lsp = 4,
		lint = 4,
	},
	bootstrap = {
		on_vim_enter = true,
		max_files_per_tick = 32,
	},
	debounce_ms = 250,
	idle_ms = 2000,
	max_hidden_buffers = 16,
	cache_path = "",
	notify_on_error = true,
	log_level = "debug",
	lsp_timeout_ms = 5000,
	window = {
		width_ratio = 0.8,
		height_ratio = 0.6,
		border = "rounded",
	},
}

---@type DoktorConfig
local current = vim.deepcopy(DEFAULTS)

---@return string
local function workspace_hash()
	return vim.fn.sha256(vim.fn.getcwd())
end

---@return string
local function default_cache_path()
	return table.concat({
		vim.fn.stdpath("cache"),
		"doktor",
		workspace_hash() .. ".json",
	}, "/")
end

---@param base table
---@param override table
---@return table
local function deep_merge(base, override)
	local result = vim.deepcopy(base)

	for key, value in pairs(override) do
		if type(value) == "table" and type(result[key]) == "table" and not vim.islist(value) then
			result[key] = deep_merge(result[key], value)
		else
			result[key] = vim.deepcopy(value)
		end
	end

	return result
end

---@param opts? table
---@return DoktorConfig
function M.setup(opts)
	current = deep_merge(DEFAULTS, opts or {})
	current.cache_path = default_cache_path()
	return current
end

---@return DoktorConfig
function M.get()
	if current.cache_path == "" then
		current.cache_path = default_cache_path()
	end

	return current
end

---@return string
function M.workspace_hash()
	return workspace_hash()
end

return M
