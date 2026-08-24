---@type Adapter
return {
	filetypes = { "haskell" },
	lsp = "hls",
	lsp_cmd = { "haskell-language-server-wrapper", "--lsp" },
	formatter = "fourmolu",
	formatter_cmd = { "fourmolu" },
	linter = "hlint",
	linter_cmd = { "hlint" },
	treesitter = "haskell",
	compiler = "ghc",
	compiler_cmd = { "runghc", "$FILE" },
}
