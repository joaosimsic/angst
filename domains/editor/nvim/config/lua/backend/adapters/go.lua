---@type Adapter
return {
	filetypes = { "go" },
	lsp = "gopls",
	lsp_cmd = { "gopls" },
	formatter = "goimports",
	linter = "golangcilint",
	linter_cmd = { "golangci-lint" },
	treesitter = "go",
	doktor = "go",
	doktor_cmd = { "go", "vet", "./..." },
	doktor_compiler = "go",
	doktor_linter = "golangci-lint",
	doktor_linter_cmd = { "golangci-lint", "run", "./..." },
	doktor_linter_compiler = "golangci-lint",
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
