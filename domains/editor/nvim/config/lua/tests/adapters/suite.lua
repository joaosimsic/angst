local scan_adapters = require("backend.shared.scan_adapters")

local suite = {}

local function resolve_cmd(cmd)
	if type(cmd) == "function" then
		return cmd()
	end
	return cmd
end

suite.steps = {
	{
		name = "LSP Engine Mappings",
		run = function(assert_true)
			local lsp_servers = scan_adapters("lsp")
			assert_true(type(lsp_servers) == "table", "LSP engine failed to return a table.")

			for server_name, server_opts in pairs(lsp_servers) do
				assert_true(type(server_name) == "string", "LSP server name must be a string.")

				local cmd = resolve_cmd(server_opts.cmd)
				assert_true(
					type(cmd) == "table" and #cmd > 0,
					string.format("LSP '%s' has an invalid or missing 'cmd' array.", server_name)
				)

				assert_true(
					type(server_opts.filetypes) == "table" and #server_opts.filetypes > 0,
					string.format("LSP '%s' must map to at least one filetype.", server_name)
				)
			end
		end,
	},
	{
		name = "Formatter Engine Mappings",
		run = function(assert_true)
			local formatters = scan_adapters("formatter")
			assert_true(type(formatters) == "table", "Formatter engine failed to return a table.")

			for name, opts in pairs(formatters) do
				assert_true(
					type(opts.filetypes) == "table" and #opts.filetypes > 0,
					string.format("Formatter '%s' must map to at least one filetype.", name)
				)
			end
		end,
	},
	{
		name = "Linter Engine Mappings",
		run = function(assert_true)
			local linters = scan_adapters("linter")
			assert_true(type(linters) == "table", "Linter engine failed to return a table.")

			for name, opts in pairs(linters) do
				assert_true(
					type(opts.filetypes) == "table" and #opts.filetypes > 0,
					string.format("Linter '%s' must map to at least one filetype.", name)
				)
			end
		end,
	},
	{
		name = "Treesitter Parser Mappings",
		run = function(assert_true)
			local parsers = scan_adapters("treesitter")
			assert_true(type(parsers) == "table", "Treesitter engine failed to return a table.")

			for name, opts in pairs(parsers) do
				assert_true(
					type(opts.filetypes) == "table" and #opts.filetypes > 0,
					string.format("Treesitter parser '%s' requires filetype configurations.", name)
				)
			end
		end,
	},
}

return suite
