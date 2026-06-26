---@type Adapter
return {
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	lsp = "ts_ls",
	lsp_cmd = { "typescript-language-server", "--stdio" },
	formatter = "prettierd",
	linter = "eslint_d",
	treesitter = { "javascript", "typescript", "tsx" },
	doktor_linter = "eslint",
	doktor_provider = {
		filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
		lang = {
			javascript = "javascript",
			javascriptreact = "javascript",
			typescript = "typescript",
			typescriptreact = "tsx",
		},
		query = [[
			(import_statement
			  source: (string (string_fragment) @import))

			(export_statement) @export

			(call_expression
			  function: (identifier) @_require
			  arguments: (arguments (string (string_fragment) @import))
			  (#eq? @_require "require"))

			(call_expression
			  function: (import)
			  arguments: (arguments (_) @dynamic_import))
		]],
	},
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
