---@type Adapter
return {
	filetypes = { "css", "scss", "less" },
	lsp = "cssls",
	lsp_cmd = { "vscode-css-language-server", "--stdio" },
	treesitter = "css",
}
