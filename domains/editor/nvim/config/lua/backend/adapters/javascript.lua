---@type Adapter
return {
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	lsp = "ts_ls",
	lsp_cmd = { "typescript-language-server", "--stdio" },
	formatter = "prettierd",
	linter = "eslint_d",
	treesitter = { "javascript", "typescript", "tsx" },
	doktor_linter = "eslint",
	doktor_resolver = {
		filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
		resolve = function(token, context_buf)
			local extensions = { ".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs" }
			local current_path = vim.api.nvim_buf_get_name(context_buf)
			local current_dir = vim.fn.fnamemodify(current_path, ":h")

			local function existing_file(path)
				local stat = vim.uv.fs_stat(path)
				if stat and stat.type == "file" then
					return vim.uv.fs_realpath(path) or path
				end
			end

			local function resolve_with_extensions(base)
				if existing_file(base) then
					return existing_file(base)
				end

				for _, ext in ipairs(extensions) do
					local resolved = existing_file(base .. ext)
					if resolved then
						return resolved
					end
				end

				for _, ext in ipairs(extensions) do
					local resolved = existing_file(base .. "/index" .. ext)
					if resolved then
						return resolved
					end
				end
			end

			if token:sub(1, 1) == "." then
				return resolve_with_extensions(vim.fs.normalize(current_dir .. "/" .. token))
			end

			return nil
		end,
	},
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
