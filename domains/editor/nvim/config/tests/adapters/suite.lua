local scan_adapters = require("backend.shared.scan_adapters")

local function resolve_cmd(cmd)
	if type(cmd) == "function" then
		return cmd()
	end
	return cmd
end

describe("Adapter Engine Validations", function()
	it("should validate LSP Engine Mappings", function()
		local lsp_servers = scan_adapters("lsp")
		assert.is.table(lsp_servers, "LSP engine failed to return a table.")

		for server_name, server_opts in pairs(lsp_servers) do
			assert.is.string(server_name, "LSP server name must be a string.")

			local cmd = resolve_cmd(server_opts.cmd)
			assert.is.table(cmd, string.format("LSP '%s' has an invalid or missing 'cmd' array.", server_name))
			assert.is_true(#cmd > 0, string.format("LSP '%s' cmd array cannot be empty.", server_name))

			assert.is.table(
				server_opts.filetypes,
				string.format("LSP '%s' must map to at least one filetype.", server_name)
			)
			assert.is_true(
				#server_opts.filetypes > 0,
				string.format("LSP '%s' filetypes array cannot be empty.", server_name)
			)
		end
	end)

	it("should validate Formatter Engine Mappings", function()
		local formatters = scan_adapters("formatter")
		assert.is.table(formatters, "Formatter engine failed to return a table.")

		for name, opts in pairs(formatters) do
			assert.is.table(opts.filetypes, string.format("Formatter '%s' must map to at least one filetype.", name))
			assert.is_true(#opts.filetypes > 0, string.format("Formatter '%s' filetypes array cannot be empty.", name))
		end
	end)

	it("should validate Linter Engine Mappings", function()
		local linters = scan_adapters("linter")
		assert.is.table(linters, "Linter engine failed to return a table.")

		for name, opts in pairs(linters) do
			assert.is.table(opts.filetypes, string.format("Linter '%s' must map to at least one filetype.", name))
			assert.is_true(#opts.filetypes > 0, string.format("Linter '%s' filetypes array cannot be empty.", name))
		end
	end)

	it("should validate Treesitter Parser Mappings", function()
		local parsers = scan_adapters("treesitter")
		assert.is.table(parsers, "Treesitter engine failed to return a table.")

		for name, opts in pairs(parsers) do
			assert.is.table(
				opts.filetypes,
				string.format("Treesitter parser '%s' requires filetype configurations.", name)
			)
			assert.is_true(
				#opts.filetypes > 0,
				string.format("Treesitter parser '%s' filetypes array cannot be empty.", name)
			)
		end
	end)
end)
