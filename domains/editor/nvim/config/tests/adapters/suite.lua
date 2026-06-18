vim.opt.runtimepath:prepend(vim.fn.expand("~/.local/share/tree-sitter"))

local scan_adapters = require("backend.shared.scan_adapters")
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
	assert.is_string(exe, string.format("%s '%s' has no resolvable executable", engine, tool))
	assert.is_true(
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

		assert.is_true(#parsers > 0, ("Treesitter parser '%s' binary was not found"):format(lang))

		local buf = vim.api.nvim_create_buf(false, true)

		local ok, err = pcall(function()
			vim.api.nvim_set_option_value("filetype", lang, {
				buf = buf,
			})

			vim.treesitter.start(buf, lang)
		end)

		vim.api.nvim_buf_delete(buf, { force = true })

		assert.is_true(ok, ("Treesitter parser '%s' could not attach: %s"):format(lang, err))
	end
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

		for _, adapter in pairs(all_adapters) do
			assert_executable(adapter, "lsp")
		end
	end)

	it("should validate Formatter Engine Mappings", function()
		local formatters = scan_adapters("formatter", { check_executable = true })
		assert.is.table(formatters, "Formatter engine failed to return a table.")

		for name, opts in pairs(formatters) do
			assert.is.table(opts.filetypes, string.format("Formatter '%s' must map to at least one filetype.", name))
			assert.is_true(#opts.filetypes > 0, string.format("Formatter '%s' filetypes array cannot be empty.", name))
		end

		for _, adapter in pairs(all_adapters) do
			assert_executable(adapter, "formatter")
		end
	end)

	it("should validate Linter Engine Mappings", function()
		local linters = scan_adapters("linter", { check_executable = true })
		assert.is.table(linters, "Linter engine failed to return a table.")

		for name, opts in pairs(linters) do
			assert.is.table(opts.filetypes, string.format("Linter '%s' must map to at least one filetype.", name))
			assert.is_true(#opts.filetypes > 0, string.format("Linter '%s' filetypes array cannot be empty.", name))
		end

		for _, adapter in pairs(all_adapters) do
			assert_executable(adapter, "linter")
		end
	end)

	it("should validate Treesitter Parser Mappings", function()
		local parsers = scan_adapters("treesitter", { check_executable = false })
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

		for _, adapter in pairs(all_adapters) do
			assert_parser_installed(adapter)
		end
	end)
end)
