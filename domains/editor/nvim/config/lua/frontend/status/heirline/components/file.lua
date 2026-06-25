---@type ThemePalette
local p = require("config.theme.palette").get()

---@type HeirlineComponent
local FileIcon = {
	init = function(self)
    local bufnr = self.bufnr or 0
		local filename = vim.api.nvim_buf_get_name(bufnr)
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
	provider = function(self)
    local bufnr = self.bufnr or 0
		local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
		return name == "" and "[No Name]" or string.format(" %s ", name)
	end,

	hl = { fg = p.base, bg = p.surface, bold = true },
}

---@type HeirlineComponent
local FileType = {
	provider = function(self)
    local bufnr = self.bufnr or 0
		local ft = vim.bo[bufnr].filetype
		return ft ~= "" and string.format(" %s ", ft) or ""
	end,

	hl = "HeirlineSurfaceBold",
}

---@type HeirlineComponent
local FileFormat = {
	provider = function(self)
    local bufnr = self.bufnr or 0
		local fmt = vim.bo[bufnr].fileformat
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
