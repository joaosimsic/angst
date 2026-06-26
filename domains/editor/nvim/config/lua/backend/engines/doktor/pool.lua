local control = require("plenary.async.control")

local M = {}

---@class CancellationToken
---@field cancelled boolean
---@field reason? "superseded"|"buffer_gone"|"shutdown"

---@class WorkerPool
---@field name "lsp"|"lint"
---@field concurrency integer
---@field private _in_flight integer
---@field private _semaphore table
local WorkerPool = {}
WorkerPool.__index = WorkerPool

---@param value DoktorConcurrency
---@return integer
local function resolve_concurrency(value)
	if value == "auto" then
		local available = vim.uv.available_parallelism and vim.uv.available_parallelism() or 4
		return math.max(1, available)
	end

	if type(value) == "number" then
		return math.max(1, value)
	end

	return 4
end

---@param opts { name: "lsp"|"lint", concurrency: DoktorConcurrency }
---@return WorkerPool
function M.new(opts)
	local concurrency = resolve_concurrency(opts.concurrency)
	return setmetatable({
		name = opts.name,
		concurrency = concurrency,
		_in_flight = 0,
		_semaphore = control.Semaphore.new(concurrency),
	}, WorkerPool)
end

---@generic R
---@param job async fun(token?: CancellationToken): R|nil
---@param token? CancellationToken
---@return R|nil
function WorkerPool:submit(job, token)
	if token and token.cancelled then
		return nil
	end

	local permit = self._semaphore:acquire()
	self._in_flight = self._in_flight + 1

	local result
	if token and token.cancelled then
		result = nil
	else
		local ok, value = pcall(job, token)
		result = ok and value or nil
	end

	self._in_flight = math.max(0, self._in_flight - 1)
	permit:forget()
	return result
end

---@return integer
function WorkerPool:in_flight()
	return self._in_flight
end

---@return integer
function WorkerPool:queued()
	return 0
end

M.WorkerPool = WorkerPool

return M
