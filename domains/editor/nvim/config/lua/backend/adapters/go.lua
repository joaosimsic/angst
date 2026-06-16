---@type Adapter
return {
	filetypes = { "go" },
	lsp = "gopls",
	lsp_cmd = { "gopls" },
	formatter = "goimports",
	linter = "golangcilint",
	linter_cmd = { "golangci-lint" },
	treesitter = "go",
	lsp_settings = {
		gopls = { staticcheck = true },
	},
}
