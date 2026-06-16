---@class Logger
---@field tag string
local Logger = {}
Logger.__index = Logger

---@alias Level "debug" | "info" | "warn" | "error"
---@alias LogMessage string|fun():string

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
---@param msg LogMessage
function Logger:log(level, msg)
	local current = level_map[level]
	local threshold = level_map[GLOBAL_THRESHOLD]

	if not current or current[2] < threshold[2] then
		return
	end

	if type(msg) == "function" then
		msg = msg()
	end

	local text = string.format("[%s] %s: %s", self.tag, level:upper(), msg)

	vim.schedule(function()
		vim.notify(text, current[1])
	end)
end

---@param msg LogMessage
function Logger:debug(msg)
	self:log("debug", msg)
end

---@param msg LogMessage
function Logger:info(msg)
	self:log("info", msg)
end

---@param msg LogMessage
function Logger:warn(msg)
	self:log("warn", msg)
end

---@param msg LogMessage
function Logger:error(msg)
	self:log("error", msg)
end

return Logger
