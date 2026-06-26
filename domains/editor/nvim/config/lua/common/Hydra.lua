local Keybinder = require("common.Keybinder")
local Logger = require("common.Logger")
local pallete = require("config.theme.palette").get()

---@class HydraHead
---@field [1] string
---@field [2] string|function
---@field [3]? string
---@field exit? boolean

---@class HydraConfig
---@field name string
---@field enter string
---@field heads HydraHead[]
---@field fg_color ThemePaletteKey
---@field bg_color ThemePaletteKey
---@field debug_level? Level
---@field exit_keys? string[]
---@field global? boolean
---@field bufnr? number
---@field init_binder Keybinder
---@field logger Logger

---@class ActiveHydraState
---@field name string
---@field fg_color string
---@field bg_color string

---@class Hydra
---@field name string
---@field enter string
---@field fg_color_hex string
---@field bg_color_hex string
---@field debug_level? Level
---@field heads HydraHead[]
---@field exit_keys string[]
---@field global boolean
---@field bufnr? number
---@field binder? Keybinder
---@field logger Logger
local Hydra = {}
Hydra.__index = Hydra

---@type ActiveHydraState|nil
vim.g.active_hydra = nil

---@param cfg HydraConfig
---@param bufnr number|nil
---@return Hydra
function Hydra.new(cfg, bufnr)
	local self = setmetatable({}, Hydra)
	self.name = cfg.name
	self.enter = cfg.enter

	local fg_color_key = cfg.fg_color or "fg"
	local bg_color_key = cfg.bg_color or "bg"

	self.fg_color_hex = pallete[fg_color_key]
	self.bg_color_hex = pallete[bg_color_key]

	self.heads = cfg.heads
	self.exit_keys = cfg.exit_keys or { "<Esc>", "<C-c>" }
	self.global = cfg.global or false
	self.bufnr = bufnr
	self.binder = nil

	self.debug_level = cfg.debug_level
	self.logger = Logger.new("HYDRA:" .. self.name:upper(), self.debug_level)

	self.init_binder = Keybinder.new(bufnr, "HYDRA-INIT:" .. self.name:upper())

	self.init_binder:nmap(self.enter, function()
		self:activate()
	end, { desc = "Enter " .. self.name })

	return self
end

function Hydra:set_debug_level(level)
	self.debug_level = level
	self.logger:set_threshold(level)

	if self.binder and type(self.binder.set_debug) == "function" then
		self.binder:set_debug(level == "debug")
	end
end

function Hydra:activate()
	self.logger:info(function()
		return "Activating " .. self.name
	end)

	if vim.g.active_hydra then
		self.logger:debug("Deactivating previous hydra silently")
		vim.api.nvim_exec_autocmds("User", { pattern = "HydraDeactivateSilently" })
	end

	local target_scope = self.global and nil or vim.api.nvim_get_current_buf()

	self.binder = Keybinder.new(target_scope, "HYDRA:" .. self.name:upper())

	if self.debug_level == "debug" and type(self.binder.set_debug) == "function" then
		self.binder:set_debug(true)
	end

	for _, head in ipairs(self.heads) do
		local lhs, rhs, desc = head[1], head[2], head[3]

		self.binder:nmap(lhs, function()
			self.logger:debug(function()
				return "Executing head: " .. lhs
			end)

			if type(rhs) == "function" then
				rhs()
			elseif type(rhs) == "string" then
				local keys = vim.api.nvim_replace_termcodes(rhs, true, false, true)
				vim.api.nvim_feedkeys(keys, "n", false)
			end

			if head.exit then
				self.logger:debug("Head triggered exit")
				self:deactivate()
			else
				self:refresh_statusline()
			end
		end, { desc = desc })
	end

	for _, key in ipairs(self.exit_keys) do
		self.binder:nmap(key, function()
			self.logger:info("Manual exit triggered")
			self:deactivate()
		end, { desc = "Exit Hydra" })
	end

	vim.g.active_hydra = { name = self.name, fg_color = self.fg_color_hex, bg_color = self.bg_color_hex }
	vim.cmd("redrawstatus")
end

function Hydra:purge()
	if self.init_binder then
		self.init_binder:purge()
		self.init_binder = nil
	end

	if vim.g.active_hydra and vim.g.active_hydra == self.name then
		self:deactivate()
	end
end

function Hydra:deactivate()
	if self.binder then
		self.logger:info("Deactivating")
		self.binder:purge()
		self.binder = nil

		vim.g.active_hydra = nil
		vim.cmd("redrawstatus")
	end
end

function Hydra:refresh_statusline()
	vim.cmd("redrawstatus")
end

return Hydra
