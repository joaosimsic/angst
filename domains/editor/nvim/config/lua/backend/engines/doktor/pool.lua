local M = {}

---@class CancellationToken
---@field cancelled boolean
---@field reason? "superseded"|"buffer_gone"|"shutdown"

---@class WorkerPool
---@field name "lsp"|"lint"
---@field concurrency integer
---@field private _in_flight integer
---@field private _waiters table[]
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
	return setmetatable({
		name = opts.name,
		concurrency = resolve_concurrency(opts.concurrency),
		_in_flight = 0,
		_waiters = {},
	}, WorkerPool)
end

---@param self WorkerPool
local function run_next(self)
	while self._in_flight < self.concurrency and #self._waiters > 0 do
		local item = table.remove(self._waiters, 1)
		local token = item.token

		if token and token.cancelled then
			if item.done then
				item.done(nil)
			end
		else
			self._in_flight = self._in_flight + 1
			vim.schedule(function()
				item.job(function(result)
					self._in_flight = math.max(0, self._in_flight - 1)
					if item.done then
						item.done(result)
					end
					run_next(self)
				end)
			end)
		end
	end
end

---@generic R
---@param job fun(done: fun(result: R|nil))
---@param token? CancellationToken
---@param done? fun(result: R|nil)
function WorkerPool:submit(job, token, done)
	self._waiters[#self._waiters + 1] = {
		job = job,
		token = token,
		done = done,
	}

	run_next(self)
end

---@return integer
function WorkerPool:in_flight()
	return self._in_flight
end

---@return integer
function WorkerPool:queued()
	return #self._waiters
end

M.WorkerPool = WorkerPool

return M
