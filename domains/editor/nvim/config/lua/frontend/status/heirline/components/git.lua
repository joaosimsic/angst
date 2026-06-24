---@type ThemePalette
local p = require("config.theme.palette").get()
local conditions = require("heirline.conditions")

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

	hl = { bg = p.surface },

	{ provider = " ", hl = { bg = p.surface } },

	{
		provider = function(self)
			return "* " .. self.status_dict.head
		end,
		hl = "HeirlineGit",
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
		hl = "HeirlineGitAdd",
	},

	{
		provider = function(self)
			local count = self.status_dict.changed or 0
			return count > 0 and ("~" .. count .. " ") or ""
		end,
		hl = "HeirlineGitChange",
	},

	{
		provider = function(self)
			local count = self.status_dict.removed or 0
			return count > 0 and ("-" .. count) or ""
		end,
		hl = "HeirlineGitDelete",
	},

	{ provider = " ", hl = { bg = p.surface } },
}

return { Git = Git }
