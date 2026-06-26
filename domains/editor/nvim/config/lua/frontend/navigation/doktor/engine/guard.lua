---@type Logger
local logger = require("frontend.navigation.doktor.logger")

---@class DoktorGuard
---@field locked boolean
---@field queued boolean
---@field on_scan fun()
local Guard = {}
Guard.__index = Guard

---@param on_scan fun()
---@return DoktorGuard
function Guard.new(on_scan)
	return setmetatable({
		locked = false,
		queued = false,
		on_scan = on_scan,
	}, Guard)
end

---@return boolean
function Guard:try_acquire()
	if self.locked then
		self.queued = true
		logger:debug(function()
			return "Scan already running, queued rescan"
		end)
		return false
	end
	self.locked = true
	self.queued = false
	logger:debug(function()
		return "Guard lock acquired"
	end)
	return true
end

---@return nil
function Guard:release()
	self.locked = false
	logger:debug(function()
		return "Guard lock released"
	end)
	if self.queued then
		self.queued = false
		logger:debug(function()
			return "Queued scan detected, restarting"
		end)
		if self:try_acquire() then
			vim.schedule(function()
				self.on_scan()
			end)
		end
	end
end

return Guard
