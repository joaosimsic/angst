---@type Adapter
return {
	filetypes = { "dockerfile" },
	lsp = "dockerls",
	lsp_cmd = { "docker-langserver", "--stdio" },
	treesitter = "dockerfile",
}
