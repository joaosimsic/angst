local config_mod = require("backend.engines.doktor.config")
local logging = require("backend.engines.doktor.logging")

---@class DoktorModule
---@field _graph Graph?
---@field _provider ProviderRegistry?
---@field _resolver ResolverRegistry?
---@field _scheduler Scheduler?
---@field _watcher DoktorWatcher?
---@field setup fun(opts?: table)
---@field rescan fun(path?: string)
---@field status fun(): table
---@field get_config fun(): DoktorConfig
---@field toggle fun()
---@field scan fun()
local M = {
	_graph = nil,
	_provider = nil,
	_resolver = nil,
	_scheduler = nil,
	_watcher = nil,
	_window = nil,
	_buffer = nil,
}

---@param opts? table
function M.setup(opts)
	local graph_mod = require("backend.engines.doktor.graph")
	local provider_mod = require("backend.engines.doktor.provider")
	local resolver_mod = require("backend.engines.doktor.resolver")
	local scheduler_mod = require("backend.engines.doktor.scheduler")
	local watcher_mod = require("backend.engines.doktor.watcher")
	local commands = require("backend.engines.doktor.commands")

	local config = config_mod.setup(opts)

	logging.set_threshold_all(config.log_level)

	M._graph = graph_mod.new()
	M._provider = provider_mod.from_adapters()
	M._resolver = resolver_mod.from_adapters()
	M._scheduler = scheduler_mod.new(config)
	M._watcher = watcher_mod.new({
		config = config,
		graph = M._graph,
		provider = M._provider,
		resolver = M._resolver,
		scheduler = M._scheduler,
	})

	M._watcher:setup()
	commands.setup(M)
end

---@return DoktorConfig
function M.get_config()
	return config_mod.get()
end

function M.toggle()
	require("backend.engines.doktor.commands").toggle(M)
end

---@param path? string
function M.rescan(path)
	if M._watcher then
		M._watcher:rescan(path or "")
	end
end

function M.scan()
	M.rescan(vim.api.nvim_buf_get_name(0))
end

---@return table
function M.status()
	if M._scheduler then
		return M._scheduler:status()
	end

	local default = {
		queues = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 },
		pools = {
			lsp = { in_flight = 0, queued = 0, concurrency = 0 },
			lint = { in_flight = 0, queued = 0, concurrency = 0 },
		},
		pending_lsp = 0,
	}

	return default
end

M[1] = "doktor"
M.virtual = true
M.event = "VeryLazy"
M.dependencies = { "plenary.nvim" }
M.config = function(_, opts)
	M.setup(opts)
end

---@type Plugin
return M
