---@type Adapter
return {
	filetypes = { "go" },
	lsp = "gopls",
	lsp_cmd = { "gopls" },
	formatter = "goimports",
	linter = "golangci-lint",
	treesitter = "go",
	lsp_settings = {
		gopls = { staticcheck = true },
	},
}
