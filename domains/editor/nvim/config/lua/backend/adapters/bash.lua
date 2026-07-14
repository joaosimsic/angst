---@type Adapter
return {
	filetypes = { "bash" },
	lsp = "bashls",
	lsp_cmd = { "bash-language-server", "start" },
	treesitter = "bash",
	compiler = "bash",
	compiler_cmd = { "bash", "$FILE" },
}
