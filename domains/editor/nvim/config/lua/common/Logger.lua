---@class Logger
---@field tag string
---@field threshold Level|nil
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
local HISTORY_LIMIT = 1000
local history = {}
local sequence = 0

local function emit_history_event(entry)
	vim.schedule(function()
		pcall(vim.api.nvim_exec_autocmds, "User", {
			pattern = "DebugLogAdded",
			data = entry,
		})
	end)
end

local function push_history(tag, level, text)
	sequence = sequence + 1

	local entry = {
		sequence = sequence,
		time = os.time(),
		tag = tag,
		level = level,
		message = text,
	}

	table.insert(history, entry)
	if #history > HISTORY_LIMIT then
		table.remove(history, 1)
	end

	emit_history_event(entry)
end

---@param tag string
---@param threshold Level|nil
---@return Logger
function Logger.new(tag, threshold)
	---@type Logger
	local self = setmetatable({}, Logger)
	self.tag = tag
	self.threshold = threshold
	return self
end

---@param level Level|nil
function Logger:set_threshold(level)
	self.threshold = level
end

---@param level Level
---@param msg LogMessage
function Logger:log(level, msg)
	local current = level_map[level]
	if not current then
		return
	end

	local threshold_level = self.threshold or GLOBAL_THRESHOLD
	local threshold = level_map[threshold_level]

	if type(msg) == "function" then
		msg = msg()
	end

	local text = string.format("[%s] %s: %s", self.tag, level:upper(), msg)
	push_history(self.tag, level, text)

	if current[2] < threshold[2] then
		return
	end

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

---@return table[]
function Logger.history()
	return vim.deepcopy(history)
end

function Logger.clear_history()
	history = {}
	sequence = 0
end

return Logger
