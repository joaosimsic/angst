---@type HighlightModule[]
local modules = {
	require("config.theme.groups.editor"),
	require("config.theme.groups.syntax"),
	require("config.theme.groups.treesitter"),
	require("config.theme.groups.lsp"),
}

local M = {}

---@param p ThemeColors
---@return HighlightGroups
M.get = function(p)
	---@type HighlightGroups
	local groups = {}

	for _, module in ipairs(modules) do
		groups = vim.tbl_extend("force", groups, module.get(p))
	end

	return groups
end

---@param p ThemeColors
M.apply = function(p)
	for name, opts in pairs(M.get(p)) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

return M
