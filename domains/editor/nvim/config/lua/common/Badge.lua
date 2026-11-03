local Logger = require("common.Logger")

---@alias BadgeAlign "left"|"right"

---@class Badge
---@field entries table<string, string>
---@field win number|nil
---@field buf number|nil
---@field name? string
---@field fg? string
---@field bg? string
---@field prefix string
---@field align BadgeAlign
---@field logger Logger
local Badge = {}
Badge.__index = Badge

---@param opts? {name?: string, fg?: string, bg?: string, prefix?: string, align?: BadgeAlign}
---@return Badge
function Badge.new(opts)
	opts = opts or {}
	local self = setmetatable({ entries = {} }, Badge)
	self.name = opts.name
	self.fg = opts.fg
	self.bg = opts.bg
	self.prefix = opts.prefix or "●"
	self.align = opts.align or "right"
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

	local content = " " .. self.prefix .. " " .. (select(2, next(self.entries)) or "")

	vim.bo[self.buf].modifiable = true
	vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, { content })
	vim.bo[self.buf].modifiable = false
	vim.bo[self.buf].bufhidden = "wipe"
	vim.bo[self.buf].buflisted = false

	local ui = vim.api.nvim_list_uis()[1]
	local viewport_width = ui and ui.width or vim.o.columns
	local badge_width = math.max(1, math.min(vim.fn.strdisplaywidth(content) + 2, viewport_width))

	local max_bottom = 0
	local left_badges = {}
	local right_badges = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local win_config = vim.api.nvim_win_get_config(win)
		if win_config.relative == "" then
			local window_position = vim.api.nvim_win_get_position(win)
			local window_height = vim.api.nvim_win_get_height(win)
			max_bottom = math.max(max_bottom, window_position[1] + window_height)
		elseif win_config.relative == "editor" and win_config.focusable == false and win ~= self.win then
			local align = vim.w[win].badge_align or "right"
			local alignment_bucket = align == "left" and left_badges or right_badges
			table.insert(alignment_bucket, { win = win, width = win_config.width })
		end
	end

	if self.win and vim.api.nvim_win_is_valid(self.win) then
		self.logger:debug(function()
			return "Updating badge: " .. content
		end)
		vim.api.nvim_win_set_buf(self.win, self.buf)
	else
		self.logger:debug(function()
			return "Creating badge window: " .. content
		end)
		self.win = vim.api.nvim_open_win(self.buf, false, {
			relative = "editor",
			width = badge_width,
			height = 1,
			row = max_bottom - 1,
			col = 0,
			style = "minimal",
			border = "none",
			focusable = false,
		})
	end

	vim.w[self.win].badge_align = self.align
	table.insert(self.align == "left" and left_badges or right_badges, { win = self.win, width = badge_width })

	local function position_badge(badge, col)
		local win_config = vim.api.nvim_win_get_config(badge.win)
		vim.api.nvim_win_set_config(badge.win, {
			relative = win_config.relative,
			width = win_config.width,
			height = win_config.height,
			col = col,
			row = max_bottom - 1,
			style = win_config.style,
			border = win_config.border,
			focusable = win_config.focusable,
		})
	end

	local function sort_by_column(a, b)
		return (vim.api.nvim_win_get_config(a.win).col or 0) < (vim.api.nvim_win_get_config(b.win).col or 0)
	end

	local gap = 1

	table.sort(right_badges, sort_by_column)

	local right_edge = viewport_width
	for i = #right_badges, 1, -1 do
		local badge = right_badges[i]
		position_badge(badge, right_edge - badge.width)
		right_edge = right_edge - badge.width - gap
	end

	table.sort(left_badges, sort_by_column)

	local left_edge = 0
	for _, badge in ipairs(left_badges) do
		position_badge(badge, left_edge)
		left_edge = left_edge + badge.width + gap
	end

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
	self.entries = { [id] = text }
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
