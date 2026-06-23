---@type Adapter
return {
	filetypes = { "rust" },
	lsp = "rust_analyzer",
	lsp_cmd = { "rust-analyzer" },
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
