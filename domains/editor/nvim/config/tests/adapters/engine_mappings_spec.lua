local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

return function(t)
	describe("engine mappings", function()
		it("should validate LSP Engine Mappings", function()
			local lsp_servers = t.AdapterScanner:by_tool("lsp")
			assert(type(lsp_servers) == "table", "LSP engine failed to return a table.")

			for server_name, server_opts in pairs(lsp_servers) do
				assert(type(server_name) == "string", "LSP server name must be a string.")

				local cmd = t.resolve_cmd(server_opts.cmd)
				assert(
					type(cmd) == "table",
					string.format("LSP '%s' has an invalid or missing 'cmd' array.", server_name)
				)
				assert(#cmd > 0, string.format("LSP '%s' cmd array cannot be empty.", server_name))

				assert(
					type(server_opts.filetypes) == "table",
					string.format("LSP '%s' must map to at least one filetype.", server_name)
				)
				assert(
					#server_opts.filetypes > 0,
					string.format("LSP '%s' filetypes array cannot be empty.", server_name)
				)
			end

			for _, adapter in pairs(t.all_adapters) do
				t.assert_executable(adapter, "lsp")
			end
		end)

		it("should validate Formatter Engine Mappings", function()
			local formatters = t.AdapterScanner:by_tool("formatter", { check_executable = true })
			assert(type(formatters) == "table", "Formatter engine failed to return a table.")

			for name, opts in pairs(formatters) do
				assert(
					type(opts.filetypes) == "table",
					string.format("Formatter '%s' must map to at least one filetype.", name)
				)
				assert(#opts.filetypes > 0, string.format("Formatter '%s' filetypes array cannot be empty.", name))
			end

			for _, adapter in pairs(t.all_adapters) do
				t.assert_executable(adapter, "formatter")
			end
		end)

		it("should validate Linter Engine Mappings", function()
			local linters = t.AdapterScanner:by_tool("linter", { check_executable = true })
			assert(type(linters) == "table", "Linter engine failed to return a table.")

			for name, opts in pairs(linters) do
				assert(
					type(opts.filetypes) == "table",
					string.format("Linter '%s' must map to at least one filetype.", name)
				)
				assert(#opts.filetypes > 0, string.format("Linter '%s' filetypes array cannot be empty.", name))
			end

			for _, adapter in pairs(t.all_adapters) do
				t.assert_executable(adapter, "linter")
			end
		end)

		it("should validate Treesitter Parser Mappings", function()
			local parsers = t.AdapterScanner:by_tool("treesitter", { check_executable = false })
			assert(type(parsers) == "table", "Treesitter engine failed to return a table.")

			for name, opts in pairs(parsers) do
				assert(
					type(opts.filetypes) == "table",
					string.format("Treesitter parser '%s' requires filetype configurations.", name)
				)
				assert(
					#opts.filetypes > 0,
					string.format("Treesitter parser '%s' filetypes array cannot be empty.", name)
				)
			end

			for _, adapter in pairs(t.all_adapters) do
				t.assert_parser_installed(adapter)
			end
		end)

		it("should merge shared tools across family adapters", function()
			local lsp_servers = t.AdapterScanner:by_tool("lsp", { check_executable = false })
			local gopls = lsp_servers.gopls

			assert(gopls, "gopls should be registered across the go family")
			assert(
				vim.deep_equal(gopls.filetypes, { "go", "gomod", "gowork" }),
				"gopls should serve go, gomod and gowork"
			)
			assert(
				vim.deep_equal(gopls.settings, t.all_adapters.go.lsp_settings),
				"gopls settings should come from the go adapter"
			)

			local lsp_opts = { check_executable = false }
			assert(t.AdapterScanner:supports_filetype("lsp", "gomod", lsp_opts), "gomod should be served by an LSP")
			assert(t.AdapterScanner:supports_filetype("lsp", "gowork", lsp_opts), "gowork should be served by an LSP")

			local exec_opts = { check_executable = true }
			assert(
				not t.AdapterScanner:supports_filetype("formatter", "gomod", exec_opts),
				"gomod should not map to an adapter formatter"
			)
			assert(
				not t.AdapterScanner:supports_filetype("linter", "gomod", exec_opts),
				"gomod should not map to an adapter linter"
			)
			assert(
				not t.AdapterScanner:supports_filetype("compiler", "gomod", lsp_opts),
				"gomod should not map to an adapter compiler"
			)
		end)
	end)
end
