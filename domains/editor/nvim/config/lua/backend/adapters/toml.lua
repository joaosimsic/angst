---@type Adapter
return {
	filetypes = { "toml" },
	lsp = "taplo",
	lsp_cmd = { "taplo", "lsp", "stdio" },
	lsp_root_markers = { ".git" },
	treesitter = "toml",
	formatter = "taplo",
}
