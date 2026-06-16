---@type Adapter
return {
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	lsp = "ts_ls",
	lsp_cmd = { "typescript-language-server", "--stdio" },
	formatter = "prettierd",
	linter = "eslint_d",
	treesitter = { "javascript", "typescript", "tsx" },
}
