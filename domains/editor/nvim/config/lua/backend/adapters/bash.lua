---@type Adapter
return {
	filetypes = { "bash", "sh" },
	lsp = "bashls",
	lsp_cmd = { "bash-language-server", "start" },
	treesitter = "bash",
	doktor_linter = "shellcheck",
	doktor_linter_cmd = { "shellcheck", "-f", "gcc" },
	doktor_linter_compiler = "shellcheck",
}
