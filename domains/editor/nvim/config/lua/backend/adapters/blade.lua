---@type Adapter
return {
	filetypes = { "blade" },
	formatter = "blade_formatter",
	formatter_cmd = { "blade-formatter", "$FILENAME" },
	treesitter = "blade",
}
