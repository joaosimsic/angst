---@type Adapter
return {
	filetypes = { "c", "cpp" },
	lsp = "clangd",
	lsp_cmd = { "clangd" },
	treesitter = { "c", "cpp" },
	compiler = { "gcc", "g++" },
	compiler_cmd = {
		gcc = { "sh", "-c", "gcc $FILE -o /tmp/scratch_out 2>&1 && /tmp/scratch_out" },
		["g++"] = { "sh", "-c", "g++ $FILE -o /tmp/scratch_out 2>&1 && /tmp/scratch_out" },
	},
}
