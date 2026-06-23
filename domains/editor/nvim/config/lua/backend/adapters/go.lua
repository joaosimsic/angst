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
		gopls = {
			hints = {
				assignVariableTypes = true,
				compositeLiteralFields = true,
				compositeLiteralTypes = true,
				constantValues = true,
				functionTypeParameters = true,
				ignoredError = true,
				parameterNames = true,
				rangeVariableTypes = true,
			},
			staticcheck = true,
		},
	},
}
