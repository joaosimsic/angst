---@type Adapter
return {
	filetypes = { "bash", "sh" },
	lsp = "bashls",
	lsp_cmd = { "bash-language-server", "start" },
	treesitter = "bash",
	formatter = "shfmt",
	linter = "shellcheck",
	compiler = "bash",
	compiler_cmd = { "bash", "$FILE" },
}
