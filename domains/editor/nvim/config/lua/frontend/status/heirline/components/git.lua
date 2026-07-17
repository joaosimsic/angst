local palette = require("config.theme.palette")
local p, a = palette.p, palette.a
local utils = require("frontend.status.heirline.utils")

---@param active_hl_name string
---@param fallback_color string
local function git_hl(active_hl_name, fallback_color)
	return function(self)
		if utils.is_active(self) then
			return active_hl_name
		end
		return { fg = utils.apply_dark_filter(fallback_color, 0.65), bg = utils.status_bg(self, p.background.variant) }
	end
end

---@type HeirlineComponent
local Git = {
	condition = function(self)
		local bufnr = self.bufnr or 0
		return vim.b[bufnr].gitsigns_head or vim.b[bufnr].gitsigns_status_dict
	end,

	init = function(self)
		local bufnr = self.bufnr or 0
		self.status_dict = vim.b[bufnr].gitsigns_status_dict
		self.has_changes = self.status_dict
			and (
				(self.status_dict.added and self.status_dict.added > 0)
				or (self.status_dict.changed and self.status_dict.changed > 0)
				or (self.status_dict.removed and self.status_dict.removed > 0)
			)
	end,

	update = { "User", "BufEnter", "WinEnter", "WinLeave", "FocusGained", "FocusLost" },

	hl = function(self)
		return utils.is_active(self) and "HeirlineSurface" or { bg = utils.status_bg(self, p.background.variant) }
	end,

	{
		provider = " ",
	},

	{
		provider = function(self)
			if not self.status_dict then
				return ""
			end
			return "* " .. (self.status_dict.head or "")
		end,
		hl = git_hl("HeirlineGit", p.foreground.variant),
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
		hl = git_hl("HeirlineGitAdd", a.success),
	},

	{
		provider = function(self)
			local count = self.status_dict.changed or 0
			return count > 0 and ("~" .. count .. " ") or ""
		end,
		hl = git_hl("HeirlineGitChange", a.warn),
	},

	{
		provider = function(self)
			local count = self.status_dict.removed or 0
			return count > 0 and ("-" .. count) or ""
		end,
		hl = git_hl("HeirlineGitDelete", a.error),
	},

	{
		provider = " ",
	},
}

return { Git = Git }
