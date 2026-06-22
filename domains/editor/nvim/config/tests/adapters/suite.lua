vim.opt.runtimepath:prepend(vim.fn.expand("~/.local/share/tree-sitter"))

local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

local AdapterScanner = require("backend.shared.AdapterScanner")
local AdapterLoader = require("backend.shared.AdapterLoader")
local all_adapters = require("backend.adapters")

local function resolve_cmd(cmd)
	if type(cmd) == "function" then
		return cmd()
	end
	return cmd
end

local function get_executable(adapter, engine)
	local cmd = resolve_cmd(adapter[engine .. "_cmd"])

	if type(cmd) == "table" and #cmd > 0 then
		return cmd[1]
	end

	return adapter[engine]
end

local function assert_executable(adapter, engine)
	local tool = adapter[engine]
	if type(tool) ~= "string" then
		return
	end

	local exe = get_executable(adapter, engine)
	assert(type(exe) == "string", string.format("%s '%s' has no resolvable executable", engine, tool))
	assert(
		vim.fn.executable(exe) == 1,
		string.format("%s tool '%s' executable '%s' is not available in PATH", engine, tool, exe)
	)
end

local function assert_parser_installed(adapter)
	local langs = adapter.treesitter
	if not langs then
		return
	end

	if type(langs) == "string" then
		langs = { langs }
	end

	for _, lang in ipairs(langs) do
		local parsers = vim.api.nvim_get_runtime_file(("parser/%s.so"):format(lang), true)

		if #parsers == 0 then
			local hyphenated = lang:gsub("_", "-")
			local alt_paths = vim.api.nvim_get_runtime_file(("parser/%s.so"):format(hyphenated), true)
			if #alt_paths > 0 then
				local ok = pcall(vim.treesitter.language.add, lang, { path = alt_paths[1] })
				if ok then
					parsers = { alt_paths[1] }
				end
			end
		end

		assert(#parsers > 0, ("Treesitter parser '%s' binary was not found"):format(lang))

		local buf = vim.api.nvim_create_buf(false, true)

		local ok, err = pcall(function()
			vim.api.nvim_set_option_value("filetype", lang, {
				buf = buf,
			})

			vim.treesitter.start(buf, lang)
		end)

		vim.api.nvim_buf_delete(buf, { force = true })

		assert(ok, ("Treesitter parser '%s' could not attach: %s"):format(lang, err))
	end
end

describe("Adapter Engine Validations", function()
	it("should load adapters through the shared loader", function()
		assert.are.same(AdapterLoader.load("backend.adapters"), all_adapters)
	end)

	it("should validate LSP Engine Mappings", function()
		local lsp_servers = AdapterScanner:by_tool("lsp")
		assert(type(lsp_servers) == "table", "LSP engine failed to return a table.")

		for server_name, server_opts in pairs(lsp_servers) do
			assert(type(server_name) == "string", "LSP server name must be a string.")

			local cmd = resolve_cmd(server_opts.cmd)
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

		for _, adapter in pairs(all_adapters) do
			assert_executable(adapter, "lsp")
		end
	end)

	it("should validate Formatter Engine Mappings", function()
		local formatters = AdapterScanner:by_tool("formatter", { check_executable = true })
		assert(type(formatters) == "table", "Formatter engine failed to return a table.")

		for name, opts in pairs(formatters) do
			assert(type(opts.filetypes) == "table", string.format("Formatter '%s' must map to at least one filetype.", name))
			assert(#opts.filetypes > 0, string.format("Formatter '%s' filetypes array cannot be empty.", name))
		end

		for _, adapter in pairs(all_adapters) do
			assert_executable(adapter, "formatter")
		end
	end)

	it("should validate Linter Engine Mappings", function()
		local linters = AdapterScanner:by_tool("linter", { check_executable = true })
		assert(type(linters) == "table", "Linter engine failed to return a table.")

		for name, opts in pairs(linters) do
			assert(type(opts.filetypes) == "table", string.format("Linter '%s' must map to at least one filetype.", name))
			assert(#opts.filetypes > 0, string.format("Linter '%s' filetypes array cannot be empty.", name))
		end

		for _, adapter in pairs(all_adapters) do
			assert_executable(adapter, "linter")
		end
	end)

	it("should validate Treesitter Parser Mappings", function()
		local parsers = AdapterScanner:by_tool("treesitter", { check_executable = false })
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

		for _, adapter in pairs(all_adapters) do
			assert_parser_installed(adapter)
		end
	end)
end)
