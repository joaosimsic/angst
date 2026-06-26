---@type Adapter
return {
	filetypes = { "python" },
	lsp = "pyright",
	lsp_cmd = { "pyright-langserver", "--stdio" },
	formatter = "black",
	linter = "pylint",
	treesitter = "python",
	doktor_linter = "ruff",
}
