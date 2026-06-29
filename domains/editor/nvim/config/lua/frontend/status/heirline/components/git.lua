---@type ThemeColors
local c = require("config.theme.colors").get()
local conditions = require("heirline.conditions")
local utils = require("frontend.status.heirline.utils")

---@param active_hl_name string
---@param fallback_color string
local function git_hl(active_hl_name, fallback_color)
	return function(self)
		if utils.is_active(self) then
			return active_hl_name
		end
		return { fg = utils.apply_dark_filter(fallback_color, 0.65), bg = utils.status_bg(self, c.status.bg) }
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

	update = { "User", "BufEnter" },

	hl = function(self)
		return utils.is_active(self) and "HeirlineSurface" or { bg = utils.status_bg(self, c.status.bg) }
	end,

	{
		provider = " ",
	},

	{
		provider = function(self)
			return "* " .. self.status_dict.head
		end,
		hl = git_hl("HeirlineGit", c.git.branch),
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
		hl = git_hl("HeirlineGitAdd", c.git.add),
	},

	{
		provider = function(self)
			local count = self.status_dict.changed or 0
			return count > 0 and ("~" .. count .. " ") or ""
		end,
		hl = git_hl("HeirlineGitChange", c.git.change),
	},

	{
		provider = function(self)
			local count = self.status_dict.removed or 0
			return count > 0 and ("-" .. count) or ""
		end,
		hl = git_hl("HeirlineGitDelete", c.git.delete),
	},

	{
		provider = " ",
	},
}

return { Git = Git }
