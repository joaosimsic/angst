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
				assert(type(cmd) == "table", string.format("LSP '%s' has an invalid or missing 'cmd' array.", server_name))
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
	end)
end
