local LspTool = require("backend.shared.LspTool")

local root_markers = { "go.work", "go.mod", ".git" }

---@type Adapter
return {
	filetypes = { "go" },
	lsp = "gopls",
	lsp_cmd = { "gopls" },
	lsp_root_markers = root_markers,
	lsp_root_dir = LspTool.make_root_dir_finder(root_markers),
	formatter = "goimports",
	linter = "golangcilint",
	linter_cmd = { "golangci-lint" },
	treesitter = "go",
	lsp_settings = {
		gopls = {
			fileWatcher = "fsnotify",
			analyses = {
				ST1000 = false,
			},
			hints = {
				assignVariableTypes = true,
				compositeLiteralFields = true,
				compositeLiteralTypes = true,
				constantValues = true,
				functionTypeParameters = true,
				ignoredError = true,
				parameterNames = true,
				rangeVariableTypes = true,
			},
			staticcheck = true,
			analyses = {
				ST1000 = false,
			},
		},
	},
	compiler = "go",
	compiler_cmd = { "go", "run", "$FILE" },
}
