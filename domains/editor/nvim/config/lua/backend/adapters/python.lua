---@type Adapter
return {
	filetypes = { "python" },
	lsp = "pyright",
	lsp_cmd = { "pyright-langserver", "--stdio" },
	formatter = "black",
	linter = "pylint",
	treesitter = "python",
	doktor = "mypy",
	doktor_cmd = { "mypy", "." },
	doktor_compiler = "mypy",
	doktor_linter = "ruff",
	doktor_linter_cmd = { "ruff", "check", "." },
	doktor_linter_compiler = "ruff",
}
