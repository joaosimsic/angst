local Logger = require("common.Logger")

---@alias Registry { modes: string[], lhs: string }

---@class Keybinder
---@field bufnr number|nil
---@field signature string|nil
---@field debug boolean
---@field logger Logger
---@field history Registry[]
local Keybinder = {}
Keybinder.__index = Keybinder

---@param bufnr number|nil
---@param signature string|nil
---@return Keybinder
function Keybinder.new(bufnr, signature)
	local self = setmetatable({}, Keybinder)
	self.bufnr = bufnr
	self.signature = signature
	self.debug = false
	self.history = {}

	local tag = "KEYBINDER" .. (signature and (":" .. signature:upper()) or "")
	self.logger = Logger.new(tag)

	return self
end

---@param enabled boolean
function Keybinder:set_debug(enabled)
	if self.debug == enabled then
		return
	end

	self.debug = enabled

	if enabled then
		self.logger:set_threshold("debug")
		self.logger:info("Key logging debug mode ENABLED")
	else
		self.logger:set_threshold(nil)
	end
end

---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param desc string|nil
function Keybinder:_bind(mode, lhs, rhs, desc)
	local opts = {
		remap = false,
		silent = true,
	}

	local action_desc = desc or (type(rhs) == "string" and rhs or "anonymous function")

	if desc and self.signature then
		opts.desc = string.format("[%s] %s", self.signature:upper(), desc)
	elseif desc then
		opts.desc = desc
	end

	if self.bufnr then
		opts.buffer = self.bufnr
	end

	local final_rhs = rhs

	if type(rhs) ~= "function" then
		self.logger:error(function()
			return string.format("Invalid RHS to keymap %s. Expected function but found '%s'.", lhs, type(rhs))
		end)
		return
	end

	final_rhs = function(...)
		if self.debug then
			self.logger:debug(function()
				return string.format("Pressed: %s -> Executing: %s", lhs, action_desc)
			end)
		end
		return rhs(...)
	end

	self.logger:debug(function()
		local modes = type(mode) == "table" and table.concat(mode, ", ") or mode
		return string.format("Mapping %s -> %s [%s]", lhs, modes, action_desc)
	end)

	table.insert(self.history, {
		modes = type(mode) == "table" and mode or { mode },
		lhs = lhs,
	})

	if type(mode) == "table" then
		for _, m in ipairs(mode) do
			vim.keymap.set(m, lhs, final_rhs, opts)
		end
		return
	end

	vim.keymap.set(mode, lhs, final_rhs, opts)
end

function Keybinder:purge()
	local opts = {}
	if self.bufnr then
		opts.buffer = self.bufnr
	end

	self.logger:debug("Purging all managed keybinds")

	for _, record in ipairs(self.history) do
		for _, m in ipairs(record.modes) do
			pcall(vim.keymap.del, m, record.lhs, opts)
		end
	end

	self.history = {}
end

---@param mode NvimMode[]
---@param lhs string
---@param rhs fun(...: any): any
---@param desc string
function Keybinder:map(mode, lhs, rhs, desc)
	self:_bind(mode, lhs, rhs, desc)
end

---@param lhs string
---@param rhs fun(...: any): any
---@param desc string
function Keybinder:nmap(lhs, rhs, desc)
	self:_bind("n", lhs, rhs, desc)
end

---@param lhs string
---@param rhs fun(...: any): any
---@param desc string
function Keybinder:imap(lhs, rhs, desc)
	self:_bind("i", lhs, rhs, desc)
end

---@param lhs string
---@param rhs fun(...: any): any
---@param desc string
function Keybinder:vmap(lhs, rhs, desc)
	self:_bind("v", lhs, rhs, desc)
end

return Keybinder
