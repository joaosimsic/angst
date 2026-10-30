local Keybinder = require("common.Keybinder")
local Logger = require("common.Logger")

---@class HydraHead
---@field [1] string
---@field [2] string|function
---@field [3]? string
---@field exit? boolean

---@class HydraConfig
---@field name string
---@field enter string
---@field heads HydraHead[]
---@field fg_color string
---@field bg_color string
---@field debug_level? Level
---@field exit_keys? string[]
---@field global? boolean
---@field persist? boolean
---@field bufnr? number
---@field hint? boolean
---@field on_enter? fun(hydra: Hydra)
---@field on_exit? fun(hydra: Hydra)
---@field logger Logger

---@class ActiveHydraState
---@field name string
---@field fg_color string
---@field bg_color string
---@field bufnr? number

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
---@field hint boolean
---@field on_enter? fun(hydra: Hydra)
---@field on_exit? fun(hydra: Hydra)
---@field binder? Keybinder
---@field hint_win? integer
---@field hint_buf? integer
---@field active_autocmds integer[]
---@field logger Logger
local Hydra = {}
Hydra.__index = Hydra

---@type ActiveHydraState|nil
vim.g.active_hydra = nil

---@type Hydra|nil
local active_hydra_instance = nil

local lifecycle_group = vim.api.nvim_create_augroup("HydraLifecycle", { clear = false })

local function notify_hydra_changed()
	vim.api.nvim_exec_autocmds("User", {
		pattern = "HydraChanged",
		data = vim.g.active_hydra,
	})
	vim.cmd("redrawstatus")
end

---@param cfg HydraConfig
---@param bufnr number|nil
---@return Hydra
function Hydra.new(cfg, bufnr)
	local self = setmetatable({}, Hydra)
	self.name = cfg.name
	self.enter = cfg.enter

	self.fg_color_hex = cfg.fg_color
	self.bg_color_hex = cfg.bg_color

	self.heads = cfg.heads
	self.exit_keys = cfg.exit_keys or { "<Esc>", "<C-c>" }
	self.global = cfg.global or false
	self.persist = cfg.persist or false
	self.hint = cfg.hint or false
	self.on_enter = cfg.on_enter
	self.on_exit = cfg.on_exit
	self.bufnr = bufnr
	self.binder = nil
	self.hint_win = nil
	self.hint_buf = nil
	self.active_autocmds = {}

	self.debug_level = cfg.debug_level
	self.logger = Logger.new("HYDRA:" .. self.name:upper(), self.debug_level)

	self.init_binder = Keybinder.new(bufnr, "HYDRA-INIT:" .. self.name:upper())

	self.init_binder:nmap(self.enter, function()
		if self.on_enter then
			self.on_enter(self)
		end
		self:activate()
	end, { desc = "Enter " .. self.name })

	return self
end

function Hydra:clear_active_autocmds()
	for _, autocmd in ipairs(self.active_autocmds) do
		pcall(vim.api.nvim_del_autocmd, autocmd)
	end

	self.active_autocmds = {}
end

---@param event string|string[]
---@param opts table
function Hydra:add_lifecycle_autocmd(event, opts)
	opts = vim.tbl_extend("force", opts, {
		group = lifecycle_group,
		callback = function()
			self:deactivate()
		end,
	})

	table.insert(self.active_autocmds, vim.api.nvim_create_autocmd(event, opts))
end

---@param bufnr number|nil
function Hydra:setup_lifecycle_autocmds(bufnr)
	self:clear_active_autocmds()

	self:add_lifecycle_autocmd("InsertEnter", self.global and {} or { buffer = bufnr })

	if not self.global and not self.persist then
		self:add_lifecycle_autocmd({ "BufLeave", "BufWipeout" }, { buffer = bufnr })
	end
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

	if active_hydra_instance then
		self.logger:debug("Deactivating previous hydra instance directly")
		active_hydra_instance:deactivate()
	elseif vim.g.active_hydra then
		self.logger:debug("Deactivating previous hydra silently")
		vim.api.nvim_exec_autocmds("User", { pattern = "HydraDeactivateSilently" })
	end

	local target_scope = self.global and nil or vim.api.nvim_get_current_buf()
	self:setup_lifecycle_autocmds(target_scope)

	self:bind_current_buf()

	active_hydra_instance = self
	vim.g.active_hydra =
		{ name = self.name, fg_color = self.fg_color_hex, bg_color = self.bg_color_hex, bufnr = target_scope }
	notify_hydra_changed()
	if self.hint then
		self:show_hint()
	end
end

function Hydra:show_hint()
	self:hide_hint()

	local lines = {}
	for _, head in ipairs(self.heads) do
		lines[#lines + 1] = string.format(" %-8s %s", head[1], head[3] or "")
	end

	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	width = width + 2

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	local ui = vim.api.nvim_list_uis()[1]
	local cols = ui and ui.width or vim.o.columns
	local rows = ui and ui.height or vim.o.lines

	local ok, win = pcall(vim.api.nvim_open_win, buf, false, {
		relative = "editor",
		width = width,
		height = #lines,
		row = math.max(0, rows - #lines - 4),
		col = math.max(0, cols - width - 2),
		style = "minimal",
		border = "single",
		focusable = false,
		title = " " .. self.name .. " ",
		title_pos = "center",
	})

	if not ok then
		self.logger:debug("Could not open hydra hint window")
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
		return
	end

	vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
	self.hint_buf = buf
	self.hint_win = win
end

function Hydra:hide_hint()
	if self.hint_win and vim.api.nvim_win_is_valid(self.hint_win) then
		vim.api.nvim_win_close(self.hint_win, true)
	end
	self.hint_win = nil
	self.hint_buf = nil
end

function Hydra:toggle_hint()
	if self.hint_win and vim.api.nvim_win_is_valid(self.hint_win) then
		self:hide_hint()
	else
		self:show_hint()
	end
end

function Hydra:bind_current_buf()
	if self.binder then
		self.binder:purge()
	end

	-- NOTE: `self.global and nil or buf` never yields nil in Lua.
	local target_scope = vim.api.nvim_get_current_buf()
	if self.global then
		target_scope = nil
	end
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
				if self.persist then
					self:bind_current_buf()
				end
			end
		end, { desc = desc })
	end

	for _, key in ipairs(self.exit_keys) do
		self.binder:nmap(key, function()
			self.logger:info("Manual exit triggered")
			self:deactivate()
		end, { desc = "Exit Hydra" })
	end

	local has_help = false
	for _, head in ipairs(self.heads) do
		if head[1] == "?" then
			has_help = true
			break
		end
	end
	if not has_help then
		self.binder:nmap("?", function()
			self:toggle_hint()
		end, { desc = "Toggle help" })
	end
end

function Hydra:purge()
	if self.init_binder then
		self.init_binder:purge()
		self.init_binder = nil
	end

	if vim.g.active_hydra and vim.g.active_hydra.name == self.name then
		self:deactivate()
	end
end

function Hydra:deactivate()
	if self.binder then
		self.logger:info("Deactivating")
		if self.on_exit then
			pcall(self.on_exit, self)
		end
		self:clear_active_autocmds()
		self:hide_hint()
		self.binder:purge()
		self.binder = nil

		if active_hydra_instance == self then
			active_hydra_instance = nil
		end
		vim.g.active_hydra = nil
		notify_hydra_changed()
	end
end

function Hydra:refresh_statusline()
	notify_hydra_changed()
end

return Hydra
