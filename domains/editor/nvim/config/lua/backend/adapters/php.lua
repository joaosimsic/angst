---@type Adapter
return {
	filetypes = { "php" },
	lsp = "intelephense",
	lsp_cmd = { "intelephense", "--stdio" },
	formatter = "blade-formatter",
	treesitter = "php",
}
