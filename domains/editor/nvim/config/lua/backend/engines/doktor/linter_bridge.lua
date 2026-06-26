local M = {}
local logging = require("backend.engines.doktor.logging")
local log = logging.for_module("linter_bridge")

---@class LinterDiagnosticsResult
---@field path string
---@field diagnostics vim.Diagnostic[]

---@param path string
---@return integer
local function buffer_for_path(path)
	local existing = vim.fn.bufnr(path)
	local bufnr = existing ~= -1 and existing or vim.api.nvim_create_buf(false, true)

	if existing == -1 then
		vim.api.nvim_buf_set_name(bufnr, path)
		vim.b[bufnr].doktor_managed = true
		local ok, lines = pcall(vim.fn.readfile, path)
		if ok then
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		end
	end

	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].buftype = ""
	vim.bo[bufnr].filetype = vim.filetype.match({ filename = path }) or vim.bo[bufnr].filetype
	vim.bo[bufnr].modified = false

	return bufnr
end

---@param path string
---@param linter_name string
---@param namespace integer
---@param done fun(result: LinterDiagnosticsResult|nil)
function M.lint(path, linter_name, namespace, done)
	local ok_lint, lint = pcall(require, "lint")
	if not ok_lint then
		log:warn("nvim-lint is unavailable")
		done(nil)
		return
	end

	local bufnr = buffer_for_path(path)
	local previous = vim.api.nvim_get_current_buf()

	vim.api.nvim_set_current_buf(bufnr)
	local ok = pcall(lint.try_lint, linter_name, {
		ignore_errors = true,
	})
	vim.api.nvim_set_current_buf(previous)

	if not ok then
		log:debug(function()
			return string.format("lint failed linter=%s path=%s", linter_name, path)
		end)
		done(nil)
		return
	end

	vim.defer_fn(function()
		local lint_namespace = type(lint.get_namespace) == "function" and lint.get_namespace(linter_name) or nil
		local diagnostics = lint_namespace and vim.diagnostic.get(bufnr, { namespace = lint_namespace })
			or vim.diagnostic.get(bufnr)
		vim.diagnostic.set(namespace, bufnr, diagnostics)
		done({
			path = path,
			diagnostics = diagnostics,
		})
	end, 500)
end

return M
