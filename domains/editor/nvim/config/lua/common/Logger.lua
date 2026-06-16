---@class Logger
---@field tag string
local Logger = {}
Logger.__index = Logger

---@alias Level
---| "debug"
---| "info"
---| "warn"
---| "error"

---@type table<Level, integer>
local level_map = {
	debug = vim.log.levels.DEBUG,
	info = vim.log.levels.INFO,
	warn = vim.log.levels.WARN,
	error = vim.log.levels.ERROR,
}

---@param tag string
---@return Logger
function Logger.new(tag)
	---@type Logger
	local self = setmetatable({}, Logger)

	self.tag = tag

	return self
end

---@param level Level
---@param msg string
function Logger:log(level, msg)
	vim.notify(string.format("[%s] %s", self.tag, msg), level_map[level])
end

return Logger
