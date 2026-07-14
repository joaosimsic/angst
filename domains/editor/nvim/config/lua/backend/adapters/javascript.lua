---@type Adapter
return {
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	lsp = "ts_ls",
	lsp_cmd = { "typescript-language-server", "--stdio" },
	formatter = "prettierd",
	linter = "eslint_d",
    treesitter = { "javascript", "typescript" },

	lsp_settings = {
		javascript = {
			inlayHints = {
				includeInlayEnumMemberValueHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
				includeInlayFunctionParameterTypeHints = true,
				includeInlayParameterNameHints = "all",
				includeInlayParameterNameHintsWhenArgumentMatchesName = true,
				includeInlayPropertyDeclarationTypeHints = true,
				includeInlayVariableTypeHints = true,
				includeInlayVariableTypeHintsWhenTypeMatchesName = true,
			},
		},
		typescript = {
			inlayHints = {
				includeInlayEnumMemberValueHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
				includeInlayFunctionParameterTypeHints = true,
				includeInlayParameterNameHints = "all",
				includeInlayParameterNameHintsWhenArgumentMatchesName = true,
				includeInlayPropertyDeclarationTypeHints = true,
				includeInlayVariableTypeHints = true,
				includeInlayVariableTypeHintsWhenTypeMatchesName = true,
			},
		},
	},
	compiler = { "node", "tsx" },
	compiler_cmd = {
		node = { "node", "$FILE" },
		tsx = { "npx", "tsx", "$FILE" },
	},
}
