---@type Adapter
return {
	filetypes = { "nix" },
	lsp = "nil_ls",
	lsp_cmd = { "nil" },
	formatter = "nixfmt",
	linter = { "statix", "deadnix" },
	treesitter = "nix",
}
