local LspTool = require("backend.shared.LspTool")

local root_markers = { "Cargo.toml", ".git" }

---@type Adapter
return {
	filetypes = { "rust" },
	lsp = "rust_analyzer",
	lsp_cmd = { "rust-analyzer" },
	lsp_root_dir = LspTool.make_root_dir_finder(root_markers),
	linter = "clippy",
	linter_cmd = { "cargo-clippy" },
	formatter = "rustfmt",
	treesitter = "rust",
	lsp_settings = {
		["rust-analyzer"] = {
			check = { command = "clippy" },
			inlayHints = {
				chainingHints = { enable = true },
				parameterHints = { enable = true },
				typeHints = { enable = true },
			},
		},
	},
}
