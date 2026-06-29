local M = {}

M.AdapterScanner = require("backend.shared.AdapterScanner")
M.AdapterLoader = require("backend.shared.AdapterLoader")
M.AdapterTool = require("backend.shared.AdapterTool")
M.all_adapters = require("backend.adapters")

function M.assert_equal(expected, actual, message)
	assert(actual == expected, message or ("expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual)))
end

function M.assert_same(expected, actual, message)
	assert(
		vim.deep_equal(actual, expected),
		message or ("expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
	)
end

function M.resolve_cmd(cmd)
	if type(cmd) == "function" then
		return cmd()
	end
	return cmd
end

local function get_executable(adapter, engine)
	local cmd = M.resolve_cmd(adapter[engine .. "_cmd"])

	if type(cmd) == "table" and #cmd > 0 then
		return cmd[1]
	end

	return adapter[engine]
end

function M.assert_executable(adapter, engine)
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

function M.assert_parser_installed(adapter)
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
			vim.api.nvim_set_option_value("filetype", lang, { buf = buf })
			vim.treesitter.start(buf, lang)
		end)

		vim.api.nvim_buf_delete(buf, { force = true })

		assert(ok, ("Treesitter parser '%s' could not attach: %s"):format(lang, err))
	end
end

function M.with_lsp_inlay_hint_stubs(callback)
	local AdapterScannerModule = require("backend.shared.AdapterScanner")
	local original_by_tool = AdapterScannerModule.by_tool
	local original_get_client_by_id = vim.lsp.get_client_by_id
	local original_enable = vim.lsp.inlay_hint.enable
	local original_keys = package.loaded["backend.engines.lsp.keys"]

	local buf = vim.api.nvim_create_buf(false, true)
	local state = {
		buf = buf,
		enable_calls = {},
		keymap_buf = nil,
	}

	rawset(AdapterScannerModule, "by_tool", function()
		return {}
	end)
	rawset(vim.lsp, "get_client_by_id", function(client_id)
		return {
			id = client_id,
			supports_method = function(_, method)
				return method == "textDocument/inlayHint"
			end,
		}
	end)
	rawset(vim.lsp.inlay_hint, "enable", function(enabled, opts)
		state.enable_calls[#state.enable_calls + 1] = { enabled = enabled, opts = opts }
	end)
	package.loaded["backend.engines.lsp.keys"] = {
		setup = function(attached_buf)
			state.keymap_buf = attached_buf
		end,
	}

	local ok, err = pcall(callback, state)

	rawset(AdapterScannerModule, "by_tool", original_by_tool)
	rawset(vim.lsp, "get_client_by_id", original_get_client_by_id)
	rawset(vim.lsp.inlay_hint, "enable", original_enable)
	package.loaded["backend.engines.lsp.keys"] = original_keys
	vim.api.nvim_buf_delete(buf, { force = true })

	assert(ok, err)
end

return M
