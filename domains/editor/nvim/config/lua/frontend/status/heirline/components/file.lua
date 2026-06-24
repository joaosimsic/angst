---@type ThemePalette
local p = require("config.theme.palette").get()

---@type HeirlineComponent
local FileIcon = {
	init = function(self)
		local filename = vim.api.nvim_buf_get_name(0)
		local extension = vim.fn.fnamemodify(filename, ":e")
		local icon, color = require("nvim-web-devicons").get_icon_color(filename, extension, { default = false })

		self.icon = icon
		self.icon_color = color
	end,

	hl = function(self)
		return { fg = self.icon_color, bg = p.surface }
	end,

	provider = function(self)
		return self.icon or ""
	end,
}

---@type HeirlineComponent
local FileName = {
	provider = function()
		local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
		return name == "" and "[No Name]" or string.format(" %s ", name)
	end,

	hl = { fg = p.base, bg = p.surface, bold = true },
}

---@type HeirlineComponent
local FileType = {
	provider = function()
		local ft = vim.bo.filetype
		return ft ~= "" and string.format(" %s ", ft) or ""
	end,

	hl = "HeirlineSurfaceBold",
}

---@type HeirlineComponent
local FileFormat = {
	provider = function()
		local fmt = vim.bo.fileformat
		return string.format(" %s ", fmt)
	end,

	hl = "HeirlineSurface",
}

return {
	FileIcon = FileIcon,
	FileName = FileName,
	FileType = FileType,
	FileFormat = FileFormat,
}
