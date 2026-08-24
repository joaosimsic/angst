---@type Adapter
return {
	filetypes = { "haskell" },
	lsp = "hls",
	lsp_cmd = { "haskell-language-server" },
	formatter = "ormolu",
	formatter_cmd = { "ormolu" },
	linter = "hlint",
	linter_cmd = { "hlint" },
	treesitter = "haskell",
	compiler = "ghc",
	compiler_cmd = { "runghc", "$FILE" },
}
