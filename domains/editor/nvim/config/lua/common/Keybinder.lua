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
---@param opts table|nil
function Keybinder:_bind(mode, lhs, rhs, opts)
	opts = opts or {}

	local final_opts = {
		remap = opts.remap or false,
		silent = opts.silent ~= false,
		expr = opts.expr or false,
		replace_keycodes = opts.replace_keycodes or false,
	}

	local desc = opts.desc or (type(rhs) == "string" and rhs or "anonymous function")

	if desc and self.signature then
		final_opts.desc = string.format("[%s] %s", self.signature:upper(), desc)
	elseif desc then
		final_opts.desc = desc
	end

	if self.bufnr then
		final_opts.buffer = self.bufnr
	end

	if type(rhs) ~= "function" and type(rhs) ~= "string" then
		self.logger:error(string.format("Invalid RHS to keymap %s. Must be a function or string.", lhs))
		return
	end

	local final_rhs
	if type(rhs) == "function" then
		final_rhs = function(...)
			if self.debug then
				self.logger:debug(string.format("Pressed: %s -> Executing: %s", lhs, desc))
			end
			local ok, result = pcall(rhs, ...)
			if self.debug then
				if ok then
					self.logger:debug(string.format("Completed: %s (%s)", lhs, desc))
				else
					self.logger:error(string.format("Failed: %s (%s): %s", lhs, desc, tostring(result)))
				end
			end
			if ok then
				return result
			end
			error(result)
		end
	else
		final_rhs = rhs
	end

	table.insert(self.history, {
		modes = type(mode) == "table" and mode or { mode },
		lhs = lhs,
	})

	if type(mode) == "table" then
		for _, m in ipairs(mode) do
			vim.keymap.set(m, lhs, final_rhs, final_opts)
		end
		return
	end

	vim.keymap.set(mode, lhs, final_rhs, final_opts)
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
---@param opts? table
function Keybinder:map(mode, lhs, rhs, opts)
	self:_bind(mode, lhs, rhs, opts)
end

---@param lhs string
---@param rhs fun(...: any): any
---@param opts? table
function Keybinder:nmap(lhs, rhs, opts)
	self:_bind("n", lhs, rhs, opts)
end

---@param lhs string
---@param rhs fun(...: any): any
---@param opts? table
function Keybinder:imap(lhs, rhs, opts)
	self:_bind("i", lhs, rhs, opts)
end

---@param lhs string
---@param rhs fun(...: any): any
---@param opts? table
function Keybinder:vmap(lhs, rhs, opts)
	self:_bind("v", lhs, rhs, opts)
end

return Keybinder
