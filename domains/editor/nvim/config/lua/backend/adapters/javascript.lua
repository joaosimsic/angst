---@type Adapter
return {
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	lsp = "ts_ls",
	lsp_cmd = { "typescript-language-server", "--stdio" },
	formatter = "prettierd",
	linter = "eslint_d",
	treesitter = { "javascript", "typescript", "tsx" },
	doktor = "tsc",
	doktor_cmd = { "npx", "tsc", "--noEmit", "--incremental" },
	doktor_compiler = "tsc",
	doktor_linter = "eslint",
	doktor_linter_cmd = { "npx", "eslint", "." },
	doktor_linter_compiler = "eslint",
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
}
