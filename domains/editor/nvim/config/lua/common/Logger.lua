---@class Logger
---@field tag string
local Logger = {}
Logger.__index = Logger

---@alias Level "debug" | "info" | "warn" | "error"

local level_map = {
	debug = { vim.log.levels.DEBUG, 1 },
	info = { vim.log.levels.INFO, 2 },
	warn = { vim.log.levels.WARN, 3 },
	error = { vim.log.levels.ERROR, 4 },
}

local GLOBAL_THRESHOLD = "warn"

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
	local current_score = level_map[level][2]
	local threshold_score = level_map[GLOBAL_THRESHOLD][2]

	if current_score < threshold_score then
		return
	end

	local text = string.format("[%s] %s: %s", self.tag, level:upper(), msg)

	vim.schedule(function()
		vim.notify(text, level_map[level][1])
	end)
end

return Logger
