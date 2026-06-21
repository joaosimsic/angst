local Logger = require("common.Logger")

---@class Keybinder
---@field bufnr number|nil
---@field signature string|nil
---@field debug boolean
---@field logger Logger
---@field bound_keys table<string, boolean>
local Keybinder = {}
Keybinder.__index = Keybinder

local active_listener_id = nil
local active_instances = {}

---@param bufnr number|nil
---@param signature string|nil
---@return Keybinder
function Keybinder.new(bufnr, signature)
	local self = setmetatable({}, Keybinder)
	self.bufnr = bufnr
	self.signature = signature
	self.debug = false
	self.bound_keys = {}

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

	if not enabled then
		self.logger:set_threshold(nil)
		active_instances[self] = nil

		if vim.tbl_isempty(active_instances) and active_listener_id then
			vim.on_key(nil, active_listener_id)
			active_listener_id = nil
			self.logger:info("Global key logging DISABLED")
		end

		return
	end

	self.logger:set_threshold("debug")
	active_instances[self] = true

	if active_listener_id then
		return
	end

	local key_buffer = ""
	local reset_timer = nil

	active_listener_id = vim.on_key(function(key)
		if key == "" then
			return
		end

		key_buffer = key_buffer .. key

		if reset_timer then
			reset_timer:stop()
		end
		reset_timer = vim.defer_fn(function()
			key_buffer = ""
		end, 500)

		local matched = false

		for instance in pairs(active_instances) do
			if instance.bound_keys[key] then
				matched = true
				instance.logger:debug(function()
					return string.format("Pressed: %s (raw: %s)", vim.fn.keytrans(key), key)
				end)
			elseif instance.bound_keys[key_buffer] then
				matched = true
				local readable = vim.fn.keytrans(key_buffer)
				local raw = key_buffer
				instance.logger:debug(function()
					return string.format("Pressed: %s (raw: %s)", readable, raw)
				end)
			end
		end

		if matched then
			key_buffer = ""
		end
	end)

	self.logger:info("Global key logging ENABLED")
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

	if desc and self.signature then
		opts.desc = string.format("[%s] %s", self.signature:upper(), desc)
	end

	if self.bufnr then
		opts.buffer = self.bufnr
	end

	local final_rhs = rhs
	if type(rhs) == "function" then
		final_rhs = function(...)
			if self.debug then
				self.logger:debug(function()
					return string.format("Pressed: %s (via Function Hook)", lhs)
				end)
			end
			return rhs(...)
		end
	elseif type(rhs) == "string" then
		final_rhs = function()
			if self.debug then
				self.logger:debug(function()
					return string.format("Pressed: %s (via String Hook: %s)", lhs, rhs)
				end)
			end
			vim.cmd(rhs)
		end
	end

	local standardized_lhs = lhs
	local leader = vim.g.mapleader or " "
	standardized_lhs = standardized_lhs:gsub("<[lL]eader>", leader)

	local raw_lhs = vim.api.nvim_replace_termcodes(standardized_lhs, true, true, true)
	self.bound_keys[raw_lhs] = true

	self.logger:debug(function()
		local modes = type(mode) == "table" and table.concat(mode, ", ") or mode
		return string.format("Mapping %s -> %s", lhs, modes)
	end)

	if type(mode) == "table" then
		for _, m in ipairs(mode) do
			vim.keymap.set(m, lhs, final_rhs, opts)
		end
		return
	end

	vim.keymap.set(mode, lhs, final_rhs, opts)
end

function Keybinder:map(mode, lhs, rhs, desc)
	self:_bind(mode, lhs, rhs, desc)
end

function Keybinder:nmap(lhs, rhs, desc)
	self:_bind("n", lhs, rhs, desc)
end

function Keybinder:imap(lhs, rhs, desc)
	self:_bind("i", lhs, rhs, desc)
end

function Keybinder:vmap(lhs, rhs, desc)
	self:_bind("v", lhs, rhs, desc)
end

-- Add this temporarily to the bottom of Keybinder.lua
function Keybinder.debug_print_bounds()
	print("--- ACTIVE KEYBINDER INSTANCES ---")
	for instance in pairs(active_instances) do
		print(
			string.format("Instance Signature: %s (Bufnr: %s)", instance.signature or "Global", instance.bufnr or "All")
		)
		for raw_key, _ in pairs(instance.bound_keys) do
			print(string.format("  -> Bound string: %s (Raw length: %d)", vim.fn.keytrans(raw_key), #raw_key))
		end
	end
end

return Keybinder
