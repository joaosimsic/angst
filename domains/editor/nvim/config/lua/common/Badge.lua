local Logger = require("common.Logger")

---@class Badge
---@field entries table<string, string>
---@field win number|nil
---@field buf number|nil
---@field logger Logger
local Badge = {}
Badge.__index = Badge

---@param opts? {name?: string, fg?: string, bg?: string, prefix?: string}
---@return Badge
function Badge.new(opts)
	opts = opts or {}
	local self = setmetatable({ entries = {} }, Badge)
	self.name = opts.name
	self.fg = opts.fg
	self.bg = opts.bg
	self.prefix = opts.prefix or "●"
	self.logger = Logger.new("BADGE:" .. (opts.name and opts.name:upper() or "?"))
	return self
end

function Badge:_close()
	self.logger:debug(function()
		return "Closing badge window"
	end)

	if self.win and vim.api.nvim_win_is_valid(self.win) then
		vim.api.nvim_win_close(self.win, true)
	end

	self.win = nil
	self.buf = nil
end

function Badge:_refresh()
	if not next(self.entries) then
		self.logger:debug("No entries, hiding badge")
		self:_close()
		return
	end

	if not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then
		self.buf = vim.api.nvim_create_buf(false, true)
	end

	local texts = {}

	for _, text in pairs(self.entries) do
		table.insert(texts, text)
	end

	local content = " " .. self.prefix .. " " .. table.concat(texts, " ┃ " .. self.prefix .. " ")

	vim.bo[self.buf].modifiable = true
	vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, { content })
	vim.bo[self.buf].modifiable = false
	vim.bo[self.buf].bufhidden = "wipe"
	vim.bo[self.buf].buflisted = false

	if self.win and vim.api.nvim_win_is_valid(self.win) then
		self.logger:debug(function()
			return "Updating badge: " .. content
		end)
		vim.api.nvim_win_set_buf(self.win, self.buf)
		return
	end

	self.logger:debug(function()
		return "Creating badge window: " .. content
	end)

	local ui = vim.api.nvim_list_uis()[1]
	local width = vim.fn.strdisplaywidth(content) + 2

	local max_bottom = 0
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local config = vim.api.nvim_win_get_config(win)
		if config.relative == "" then
			local pos = vim.api.nvim_win_get_position(win)
			local height = vim.api.nvim_win_get_height(win)
			max_bottom = math.max(max_bottom, pos[1] + height)
		end
	end

	self.win = vim.api.nvim_open_win(self.buf, false, {
		relative = "editor",
		width = width,
		height = 1,
		row = max_bottom - 1,
		col = ui.width - width,
		style = "minimal",
		border = "none",
		focusable = false,
	})

	if self.fg or self.bg then
		local hl_name = "Badge" .. (self.name or "Default")
		vim.api.nvim_set_hl(0, hl_name, { fg = self.fg, bg = self.bg })
		vim.api.nvim_set_option_value("winhl", "Normal:" .. hl_name, { win = self.win })
	end
end

---@param id string
---@param text string
function Badge:show(id, text)
	self.logger:debug(function()
		return string.format("show('%s', '%s')", id, text)
	end)
	self.entries[id] = text
	self:_refresh()
end

function Badge:hide(id)
	self.logger:debug(function()
		return string.format("hide('%s')", id)
	end)
	self.entries[id] = nil
	self:_refresh()
end

return Badge
