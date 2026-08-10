---@type Adapter
return {
	filetypes = { "json", "jsonc" },
	lsp = "jsonls",
	lsp_cmd = { "vscode-json-language-server", "--stdio" },
	formatter = "fixjson",
	treesitter = { "json", "jsonc" },
}
