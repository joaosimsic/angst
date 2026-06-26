local Logger = require("common.Logger")

---@class DoktorLoggerRegistry
---@field private _loggers table<string, Logger>
local M = {
	_loggers = {},
	_threshold = nil,
}

local TAGS = {
	init = "DOKTOR",
	config = "DOKTOR:CONFIG",
	graph = "DOKTOR:GRAPH",
	provider = "DOKTOR:PROVIDER",
	resolver = "DOKTOR:RESOLVER",
	scheduler = "DOKTOR:SCHEDULER",
	pool = "DOKTOR:POOL",
	lsp_bridge = "DOKTOR:LSP_BRIDGE",
	linter_bridge = "DOKTOR:LINTER_BRIDGE",
	watcher = "DOKTOR:WATCHER",
	cache = "DOKTOR:CACHE",
	commands = "DOKTOR:COMMANDS",
}

---@param module_name string
---@return Logger
function M.for_module(module_name)
	local key = module_name or "init"
	if not M._loggers[key] then
		M._loggers[key] = Logger.new(TAGS[key] or ("DOKTOR:" .. key:upper()), M._threshold)
	end

	return M._loggers[key]
end

---@param level Level|nil
function M.set_threshold_all(level)
	M._threshold = level
	for _, logger in pairs(M._loggers) do
		logger:set_threshold(level)
	end
end

---@return table<string, Logger>
function M.all()
	return M._loggers
end

return M
