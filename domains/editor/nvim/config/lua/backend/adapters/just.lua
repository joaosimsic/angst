---@type Adapter
return {
	filetypes = { "just" },
	lsp = "just_lsp",
	lsp_cmd = { "just-lsp" },
	treesitter = "just",
	formatter = "just-formatter",
	compiler = "just",
	compiler_cmd = { "just", "--justfile", "$FILE" },
}
