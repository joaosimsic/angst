local LspTool = require("backend.shared.LspTool")

local root_markers = { "ols.json", ".git" }

---@type Adapter
return {
	filetypes = { "odin" },
	lsp = "ols",
	lsp_cmd = { "ols" },
	lsp_root_markers = root_markers,
	lsp_root_dir = LspTool.make_root_dir_finder(root_markers),
	treesitter = "odin",
	compiler = "odin",
	compiler_cmd = { "odin", "run", "$FILE", "-file" },
}
