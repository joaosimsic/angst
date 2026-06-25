---@type ThemePalette
local p = require("config.theme.palette").get()
local conditions = require("heirline.conditions")
local utils = require("frontend.status.heirline.utils")

---@param color string
---@return fun(self: table): vim.api.keyset.highlight
local function git_hl(color)
	return function(self)
		return { fg = utils.status_color(self, color), bg = utils.status_bg(self, p.surface) }
	end
end

---@type HeirlineComponent
local Git = {
	condition = function()
		return conditions.is_git_repo() and vim.b.gitsigns_status_dict ~= nil
	end,

	init = function(self)
		self.status_dict = vim.b.gitsigns_status_dict or {}
		self.has_changes = (self.status_dict.added or 0) ~= 0
			or (self.status_dict.removed or 0) ~= 0
			or (self.status_dict.changed or 0) ~= 0
	end,

	hl = function(self)
		return { bg = utils.status_bg(self, p.surface) }
	end,

	{
		provider = " ",
		hl = function(self)
			return { bg = utils.status_bg(self, p.surface) }
		end,
	},

	{
		provider = function(self)
			return "* " .. self.status_dict.head
		end,
		hl = git_hl(p.bright),
	},

	{
		condition = function(self)
			return self.has_changes
		end,
		provider = " ",
	},

	{
		provider = function(self)
			local count = self.status_dict.added or 0
			return count > 0 and ("+" .. count .. " ") or ""
		end,
		hl = git_hl(p.green),
	},

	{
		provider = function(self)
			local count = self.status_dict.changed or 0
			return count > 0 and ("~" .. count .. " ") or ""
		end,
		hl = git_hl(p.yellow),
	},

	{
		provider = function(self)
			local count = self.status_dict.removed or 0
			return count > 0 and ("-" .. count) or ""
		end,
		hl = git_hl(p.red),
	},

	{
		provider = " ",
		hl = function(self)
			return { bg = utils.status_bg(self, p.surface) }
		end,
	},
}

return { Git = Git }
