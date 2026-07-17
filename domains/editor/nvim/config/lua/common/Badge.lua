local Logger = require("common.Logger")

---@class Badge
---@field entries table<string, string>
---@field win number|nil
---@field buf number|nil
---@field logger Logger
local Badge = {}
Badge.__index = Badge

---@param name? string
---@return Badge
function Badge.new(name)
	local self = setmetatable({ entries = {} }, Badge)
	self.logger = Logger.new("BADGE:" .. (name and name:upper() or "?"), "debug")
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

	local content = " " .. table.concat(texts, " ┃ ")

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

	local orig_win = vim.api.nvim_get_current_win()

	vim.cmd("botright 1new")
	self.win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(self.win, self.buf)
	vim.wo[self.win].winfixheight = true
	vim.wo[self.win].number = false
	vim.wo[self.win].signcolumn = "no"
	vim.wo[self.win].statuscolumn = ""

	for _, opt in ipairs({ "foldcolumn", "spell", "cursorline", "cursorcolumn" }) do
		pcall(vim.wo.__newindex, vim.wo, self.win, opt, false)
	end

	vim.api.nvim_set_current_win(orig_win)
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
