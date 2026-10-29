---@type Adapter
return {
	filetypes = { "python" },
	lsp = "pyright",
	lsp_cmd = { "pyright-langserver", "--stdio" },
	formatter = "black",
	linter = "pylint",
	treesitter = "python",
	compiler = "python3",
	compiler_cmd = { "python3", "$FILE" },
}
