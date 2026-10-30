---@type Adapter
return {
	filetypes = { "make" },
	treesitter = "make",
	compiler = "make",
	compiler_cmd = { "make", "-f", "$FILE" },
}
