local AdapterScanner = require("backend.shared.AdapterScanner")
local pool_mod = require("backend.engines.doktor.pool")
local lsp_bridge = require("backend.engines.doktor.lsp_bridge")
local linter_bridge = require("backend.engines.doktor.linter_bridge")
local logging = require("backend.engines.doktor.logging")

local M = {}
local log = logging.for_module("scheduler")

---@class DoktorTask
---@field path string
---@field filetype string
---@field priority DoktorPriority
---@field source "lsp"|"lint"
---@field linter? string
---@field enqueued_at integer
---@field token CancellationToken

---@class Scheduler
---@field private _config DoktorConfig
---@field private _queues table<DoktorPriority, DoktorTask[]>
---@field private _pools table<string, WorkerPool>
---@field private _pending_lsp table<string, DoktorTask[]>
---@field private _tokens table<string, CancellationToken>
---@field private _scheduled boolean
---@field private _namespaces table<string, integer>
---@field private _notified table<string, true>
local Scheduler = {}
Scheduler.__index = Scheduler

---@param config DoktorConfig
---@return Scheduler
function M.new(config)
	return setmetatable({
		_config = config,
		_queues = {
			[0] = {},
			[1] = {},
			[2] = {},
			[3] = {},
		},
		_pools = {
			lsp = pool_mod.new({ name = "lsp", concurrency = config.concurrency.lsp }),
			lint = pool_mod.new({ name = "lint", concurrency = config.concurrency.lint }),
		},
		_pending_lsp = {},
		_tokens = {},
		_scheduled = false,
		_namespaces = {
			lsp = vim.api.nvim_create_namespace("doktor.lsp"),
			lint = vim.api.nvim_create_namespace("doktor.lint"),
		},
		_notified = {},
	}, Scheduler)
end

---@return table<string, integer>
function Scheduler:namespaces()
	return self._namespaces
end

---@param path string
---@param source string
---@return string
local function token_key(path, source)
	return path .. "\0" .. source
end

---@param self Scheduler
---@param path string
---@param source string
---@return CancellationToken
local function replace_token(self, path, source)
	local key = token_key(path, source)
	local previous = self._tokens[key]
	if previous then
		previous.cancelled = true
		previous.reason = "superseded"
	end

	local token = { cancelled = false }
	self._tokens[key] = token
	return token
end

---@param self Scheduler
---@param task DoktorTask
local function remove_existing(self, task)
	for priority = 0, 3 do
		local queue = self._queues[priority]
		for index = #queue, 1, -1 do
			local queued = queue[index]
			if queued.path == task.path and queued.source == task.source then
				queued.token.cancelled = true
				table.remove(queue, index)
			end
		end
	end
end

---@param self Scheduler
---@param task DoktorTask
local function notify_failure(self, task, message)
	if not self._config.notify_on_error then
		return
	end

	local key = token_key(task.path, task.source)
	if self._notified[key] then
		return
	end

	self._notified[key] = true
	log:warn(message)
end

---@param self Scheduler
---@param task DoktorTask
---@param done fun()
local function run_task(self, task, done)
	if task.token.cancelled then
		done()
		return
	end

	if task.source == "lint" then
		if not task.linter then
			done()
			return
		end

		self._pools.lint:submit(
			function(finish)
				linter_bridge.lint(task.path, task.linter, self._namespaces.lint, finish)
			end,
			task.token,
			function(result)
				if not result and not task.token.cancelled then
					notify_failure(self, task, "Doktor linter failed for " .. vim.fn.fnamemodify(task.path, ":."))
				end
				done()
			end
		)
		return
	end

	self._pools.lsp:submit(
		function(finish)
			lsp_bridge.fetch(task.path, task.filetype, self._config.lsp_timeout_ms, self._namespaces.lsp, finish)
		end,
		task.token,
		function(result)
			if not result and not task.token.cancelled then
				self._pending_lsp[task.filetype] = self._pending_lsp[task.filetype] or {}
				self._pending_lsp[task.filetype][#self._pending_lsp[task.filetype] + 1] = task
				log:debug(function()
					return string.format("park lsp task path=%s ft=%s", task.path, task.filetype)
				end)
			end
			done()
		end
	)
end

---@param self Scheduler
---@return DoktorTask|nil
local function pop_next(self)
	for priority = 0, 3 do
		local task = table.remove(self._queues[priority], 1)
		if task then
			return task
		end
	end
end

function Scheduler:drain()
	if self._scheduled then
		return
	end

	self._scheduled = true
	local function step()
		local task = pop_next(self)
		if not task then
			self._scheduled = false
			return
		end

		run_task(self, task, function()
			vim.defer_fn(step, task.priority >= 2 and self._config.idle_ms or 0)
		end)
	end

	vim.schedule(step)
end

---@param task DoktorTask
function Scheduler:enqueue(task)
	task.enqueued_at = vim.uv.hrtime()
	task.token = replace_token(self, task.path, task.source)
	remove_existing(self, task)
	self._queues[task.priority][#self._queues[task.priority] + 1] = task
	log:debug(function()
		return string.format("enqueue priority=%d source=%s path=%s", task.priority, task.source, task.path)
	end)
	self:drain()
end

---@param path string
---@param reason? "superseded"|"buffer_gone"|"shutdown"
function Scheduler:cancel(path, reason)
	for _, source in ipairs({ "lsp", "lint" }) do
		local token = self._tokens[token_key(path, source)]
		if token then
			token.cancelled = true
			token.reason = reason
		end
	end

	for priority = 0, 3 do
		local queue = self._queues[priority]
		for index = #queue, 1, -1 do
			if queue[index].path == path then
				table.remove(queue, index)
			end
		end
	end
end

---@param filetype string
function Scheduler:drain_pending_lsp(filetype)
	local pending = self._pending_lsp[filetype]
	if not pending then
		return
	end

	self._pending_lsp[filetype] = nil
	for _, task in ipairs(pending) do
		task.priority = 1
		task.token = replace_token(self, task.path, task.source)
		self._queues[1][#self._queues[1] + 1] = task
	end

	self:drain()
end

---@param path string
---@param filetype string
---@param priority DoktorPriority
function Scheduler:enqueue_diagnostics(path, filetype, priority)
	self:enqueue({
		path = path,
		filetype = filetype,
		priority = priority,
		source = "lsp",
		enqueued_at = 0,
		token = { cancelled = false },
	})

	for _, linter in ipairs(AdapterScanner:tools_for_filetype("doktor_linter", filetype)) do
		self:enqueue({
			path = path,
			filetype = filetype,
			priority = priority,
			source = "lint",
			linter = linter,
			enqueued_at = 0,
			token = { cancelled = false },
		})
	end
end

---@return table
function Scheduler:status()
	local queues = {}
	for priority = 0, 3 do
		queues[priority] = #self._queues[priority]
	end

	return {
		queues = queues,
		pools = {
			lsp = {
				in_flight = self._pools.lsp:in_flight(),
				queued = self._pools.lsp:queued(),
				concurrency = self._pools.lsp.concurrency,
			},
			lint = {
				in_flight = self._pools.lint:in_flight(),
				queued = self._pools.lint:queued(),
				concurrency = self._pools.lint.concurrency,
			},
		},
		pending_lsp = vim.tbl_count(self._pending_lsp),
	}
end

M.Scheduler = Scheduler

return M
