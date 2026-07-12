---@type HighlightModule[]
local modules = {
	require("config.theme.groups.editor"),
	require("config.theme.groups.syntax"),
	require("config.theme.groups.treesitter"),
	require("config.theme.groups.lsp"),
}

local M = {}

---@return HighlightGroups
M.get = function()
	---@type HighlightGroups
	local groups = {}

	for _, module in ipairs(modules) do
		groups = vim.tbl_extend("force", groups, module.get())
	end

	return groups
end

M.apply = function()
	for name, opts in pairs(M.get()) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

return M
