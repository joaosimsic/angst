local LspTool = require("backend.shared.LspTool")

local root_markers = { "composer.json", ".phpactor.json", ".phpactor.yml", ".git" }

---@type Adapter
return {
	filetypes = { "php" },
	lsp = "phpactor",
	lsp_cmd = { "phpactor", "language-server" },
	lsp_root_markers = root_markers,
	lsp_root_dir = LspTool.make_root_dir_finder(root_markers),
	formatter = "php_cs_fixer",
	formatter_cmd = {
		"php-cs-fixer",
		"fix",
		"$FILENAME",
		"--rules=@PSR12",
		"--using-cache=no",
		"--show-progress=none",
		"-q",
	},
	linter = "phpstan",
	linter_cmd = { "phpstan", "analyze", "--level=max", "--error-format=json", "--no-progress" },
	treesitter = "php",
	lsp_init_options = {
		["language_server_worse_reflection.inlay_hints.enable"] = true,
		["language_server_worse_reflection.inlay_hints.params"] = true,
		["language_server_worse_reflection.inlay_hints.types"] = true,
	},
}
