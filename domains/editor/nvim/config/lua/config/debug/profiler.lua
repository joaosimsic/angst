local Logger = require("common.Logger")

local M = {}
local is_profiling = false
local logger = Logger.new("Profiler", "debug")

function M.start()
	if is_profiling then
		logger:warn("Profiler is already running!")
		return
	end

	vim.cmd("profile start nvim-profile.log")
	vim.cmd("profile file *")
	vim.cmd("profile func *")

	is_profiling = true
	logger:info("Profiler started. Output: nvim-profile.log")
end

function M.stop()
	if not is_profiling then
		logger:warn("Profiler is not running.")
		return
	end

	vim.cmd("profile pause")
	is_profiling = false

	logger:info("Profiler stopped! Data saved to nvim-profile.log")
end

function M.toggle()
	if is_profiling then
		M.stop()
	else
		M.start()
	end
end

return M
