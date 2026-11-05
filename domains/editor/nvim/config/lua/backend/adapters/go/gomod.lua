local LspTool = require("backend.shared.LspTool")

local root_markers = { "go.work", "go.mod", ".git" }

---@type Adapter
return {
	filetypes = { "gomod" },
	lsp = "gopls",
	lsp_cmd = { "gopls" },
	lsp_root_markers = root_markers,
	lsp_root_dir = LspTool.make_root_dir_finder(root_markers),
	treesitter = "gomod",
}
