local Keybinder = require("common.Keybinder")

---@class HydraHead
---@field [1] string
---@field [2] string|function
---@field [3]? string
---@field exit? boolean

---@class HydraConfig
---@field name string
---@field enter string
---@field heads HydraHead[]
---@field exit_keys? string[]
---@field global? boolean

---@class ActiveHydraState
---@field name string
---@field hints string

---@class Hydra
---@field name string
---@field enter string
---@field heads HydraHead[]
---@field exit_keys string[]
---@field global boolean
---@field binder? Keybinder
local Hydra = {}
Hydra.__index = Hydra

---@type ActiveHydraState|nil
vim.g.active_hydra = nil

---@param cfg HydraConfig
---@return Hydra
function Hydra.new(cfg)
	local self = setmetatable({}, Hydra)
	self.name = cfg.name
	self.enter = cfg.enter
	self.heads = cfg.heads
	self.exit_keys = cfg.exit_keys or { "<Esc>", "<C-c>" }
	self.global = cfg.global or false
	self.binder = nil

	local init_binder = Keybinder.new(nil, "HYDRA-INIT")

	init_binder:nmap(self.enter, function()
		self:activate()
	end, "Enter " .. self.name)

	return self
end

function Hydra:activate()
	if vim.g.active_hydra then
		vim.api.nvim_exec_autocmds("User", { pattern = "HydraDeactivateSilently" })
	end

	local target_scope = self.global and nil or vim.api.nvim_get_current_buf()
	self.binder = Keybinder.new(target_scope, "HYDRA:" .. self.name:upper())

	---@type string[]
	local hints = {}

	for _, head in ipairs(self.heads) do
		local lhs, rhs, desc = head[1], head[2], head[3]
		table.insert(hints, string.format("[%s] %s", lhs, desc or ""))

		self.binder:nmap(lhs, function()
			if type(rhs) == "function" then
				rhs()
			elseif type(rhs) == "string" then
				local keys = vim.api.nvim_replace_termcodes(rhs, true, false, true)
				vim.api.nvim_feedkeys(keys, "n", false)
			end

			if head.exit then
				self:deactivate()
			else
				self:refresh_statusline()
			end
		end, desc)
	end

	for _, key in ipairs(self.exit_keys) do
		self.binder:nmap(key, function()
			self:deactivate()
		end, "Exit Hydra")
	end

	vim.g.active_hydra = { name = self.name, hints = table.concat(hints, " • ") }
	vim.cmd("redrawstatus")
end

function Hydra:deactivate()
	if self.binder then
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
