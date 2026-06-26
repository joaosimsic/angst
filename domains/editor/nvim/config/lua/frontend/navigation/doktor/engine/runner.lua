---@type Logger
local logger = require("frontend.navigation.doktor.logger")

local M = {}

---@type integer
local MAX_OUTPUT_BYTES = 10 * 1024 * 1024

---@type integer
local DEFAULT_TIMEOUT_MS = 60000

---@param output string
---@return string
local function truncate_output(output)
	if #output > MAX_OUTPUT_BYTES then
		logger:warn(function()
			return string.format("Output truncated from %d to %d bytes", #output, MAX_OUTPUT_BYTES)
		end)
		return output:sub(1, MAX_OUTPUT_BYTES)
	end
	return output
end

---@class DoktorRunResult
---@field stdout string
---@field stderr string
---@field code integer
---@field timed_out boolean
---@field kind DoktorJobKind
---@field cmd string[]
---@field compiler string

---@param job DoktorJobSpec
---@param callback fun(result: DoktorRunResult)
---@return nil
function M.run(job, callback)
	logger:info(function()
		return string.format("Spawning %s job: %s", job.kind, table.concat(job.cmd, " "))
	end)

	---@type string[]
	local stdout_chunks = {}
	---@type string[]
	local stderr_chunks = {}
	---@type boolean
	local timed_out = false

	---@type boolean, vim.SystemObj|string
	local ok, handle_or_err = pcall(vim.system, job.cmd, {
		cwd = job.cwd,
		stdout = function(_, data)
			if data then
				table.insert(stdout_chunks, data)
			end
		end,
		stderr = function(_, data)
			if data then
				table.insert(stderr_chunks, data)
			end
		end,
		timeout = DEFAULT_TIMEOUT_MS,
	}, function(result)
		---@type string
		local stdout = truncate_output(table.concat(stdout_chunks))
		---@type string
		local stderr = truncate_output(table.concat(stderr_chunks))

		if result.code == nil then
			timed_out = true
			logger:warn(function()
				return string.format("Job timed out or failed: %s", table.concat(job.cmd, " "))
			end)
		end

		logger:debug(function()
			return string.format("Job complete: code=%s, stdout=%d bytes, stderr=%d bytes",
				tostring(result.code), #stdout, #stderr)
		end)

		vim.schedule(function()
			---@type DoktorRunResult
			local run_result = {
				stdout = stdout,
				stderr = stderr,
				code = result.code or -1,
				timed_out = timed_out,
				kind = job.kind,
				cmd = job.cmd,
				compiler = job.compiler,
			}
			callback(run_result)
		end)
	end)

	if not ok or not handle_or_err then
		logger:warn(function()
			return string.format("Failed to spawn: %s — %s", table.concat(job.cmd, " "), tostring(handle_or_err))
		end)
		vim.schedule(function()
			---@type DoktorRunResult
			local fail_result = {
				stdout = "",
				stderr = tostring(handle_or_err),
				code = -1,
				timed_out = false,
				kind = job.kind,
				cmd = job.cmd,
				compiler = job.compiler,
			}
			callback(fail_result)
		end)
	end
end

return M
