---@type Adapter
return {
	filetypes = { "nix" },
	lsp = { "nil_ls", "nixd" },
	lsp_cmd = {
		nil_ls = { "nil" },
		nixd = { "nixd" },
	},
	formatter = "nixfmt",
	linter = { "statix", "deadnix" },
	treesitter = "nix",
	compiler = "nix",
	compiler_cmd = { "nix", "eval", "--file", "$FILE" },
}
