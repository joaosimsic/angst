---@type Adapter
return {
	filetypes = { "yaml", "yml" },
	lsp = "yamlls",
	lsp_cmd = { "yaml-language-server", "--stdio" },
	lsp_root_markers = { ".git" },
	treesitter = "yaml",
	formatter = "yamlfmt",
	linter = "yamllint",
}
