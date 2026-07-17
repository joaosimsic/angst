local p = require("config.theme.palette")
local utils = require("frontend.status.heirline.utils")

---@type HeirlineComponent
local FileIcon = {
	update = {
		"BufEnter",
		"BufWinEnter",
		"WinEnter",
		"WinLeave",
		"FocusGained",
		"FocusLost",
	},
	init = function(self)
		local bufnr = self.bufnr or vim.api.nvim_get_current_buf()
		local filename = vim.api.nvim_buf_get_name(bufnr)
		local extension = vim.fn.fnamemodify(filename, ":e")

		local has_devicons, devicons = pcall(require, "nvim-web-devicons")
		if has_devicons then
			local icon, color = devicons.get_icon_color(filename, extension, { default = false })
			self.icon = icon
			self.icon_color = color
		else
			self.icon = ""
			self.icon_color = p.foreground.variant
		end
	end,

	hl = function(self)
		return { fg = utils.status_color(self, self.icon_color), bg = utils.status_bg(self, p.background.variant) }
	end,

	provider = function(self)
		return self.icon or ""
	end,
}

---@type HeirlineComponent
local FileName = {
	update = {
		"BufEnter",
		"BufWinEnter",
		"WinEnter",
		"WinLeave",
		"FocusGained",
		"FocusLost",
	},
	provider = function(self)
		local bufnr = self.bufnr or 0
		local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
		return name == "" and "[No Name]" or string.format(" %s ", name)
	end,

	hl = function(self)
		return {
			fg = utils.status_color(self, p.foreground.variant),
			bg = utils.status_bg(self, p.background.variant),
			bold = true,
		}
	end,
}

---@type HeirlineComponent
local FileType = {
	update = {
		"BufEnter",
		"BufWinEnter",
		"WinEnter",
		"WinLeave",
		"FocusGained",
		"FocusLost",
	},
	provider = function(self)
		local bufnr = self.bufnr or 0
		local ft = vim.bo[bufnr].filetype
		return ft ~= "" and string.format(" %s ", ft) or ""
	end,

	hl = function(self)
		return { fg = utils.status_color(self, p.foreground.variant), bg = utils.status_bg(self, p.background.variant), bold = true }
	end,
}

---@type HeirlineComponent
local FileFormat = {
	update = {
		"BufEnter",
		"BufWinEnter",
		"WinEnter",
		"WinLeave",
		"FocusGained",
		"FocusLost",
	},
	provider = function(self)
		local bufnr = self.bufnr or 0
		local fmt = vim.bo[bufnr].fileformat
		return string.format(" %s ", fmt)
	end,

	hl = function(self)
		return { fg = utils.status_color(self, p.accent.base), bg = utils.status_bg(self, p.background.variant) }
	end,
}

return {
	FileIcon = FileIcon,
	FileName = FileName,
	FileType = FileType,
	FileFormat = FileFormat,
}
