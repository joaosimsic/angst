---@type Adapter
return {
	filetypes = { "scheme" },
	treesitter = "scheme",
	compiler = "chez",
	compiler_cmd = { "chez", "--script", "$FILE" },
}
