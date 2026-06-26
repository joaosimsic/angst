local a = require("plenary.async")
local uv = a.uv
local buffer_pool = require("backend.engines.doktor.buffer_pool")
local logging = require("backend.engines.doktor.logging")

local M = {}
local log = logging.for_module("linter_bridge")

---@class LinterDiagnosticsResult
---@field path string
---@field diagnostics vim.Diagnostic[]

---@param path string
---@return string[]|nil
local function read_lines(path)
	local fd = uv.fs_open(path, "r", 438)
	if not fd then
		return nil
	end

	local stat = uv.fs_fstat(fd)
	if not stat then
		uv.fs_close(fd)
		return nil
	end

	local data = uv.fs_read(fd, stat.size)
	uv.fs_close(fd)
	if not data then
		return nil
	end

	return vim.split(data, "\n", { plain = true })
end

---@param path string
---@param token? CancellationToken
---@return integer, boolean
local function buffer_for_path(path, token)
	local existing = vim.fn.bufnr(path)
	local bufnr = existing ~= -1 and existing or vim.api.nvim_create_buf(false, true)
	local created = existing == -1

	if created then
		vim.api.nvim_buf_set_name(bufnr, path)
		vim.b[bufnr].doktor_managed = true

		a.util.scheduler()
		if token and token.cancelled then
			return bufnr, created
		end

		local lines = read_lines(path)
		if lines then
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		end
	end

	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].buftype = ""
	vim.bo[bufnr].filetype = vim.filetype.match({ filename = path }) or vim.bo[bufnr].filetype
	vim.bo[bufnr].modified = false

	return bufnr, created
end

---@async
---@param path string
---@param linter_name string
---@param namespace integer
---@param token? CancellationToken
---@return LinterDiagnosticsResult|nil
function M.lint(path, linter_name, namespace, token)
	if token and token.cancelled then
		return nil
	end

	local ok_lint, lint = pcall(require, "lint")
	if not ok_lint then
		log:warn("nvim-lint is unavailable")
		return nil
	end

	local bufnr, created = buffer_for_path(path, token)
	if token and token.cancelled then
		buffer_pool.discard(bufnr, created)
		return nil
	end

	local diagnostics = a.wrap(function(cb)
		local finished = false
		local autocmd

		local function finish()
			if finished then
				return
			end
			finished = true

			if autocmd then
				pcall(vim.api.nvim_del_autocmd, autocmd)
			end

			local lint_namespace = type(lint.get_namespace) == "function" and lint.get_namespace(linter_name) or nil
			local diags = lint_namespace and vim.diagnostic.get(bufnr, { namespace = lint_namespace })
				or vim.diagnostic.get(bufnr)
			cb(diags)
		end

		autocmd = vim.api.nvim_create_autocmd("DiagnosticChanged", {
			buffer = bufnr,
			callback = finish,
		})

		local ok = vim.api.nvim_buf_call(bufnr, function()
			return pcall(lint.try_lint, linter_name, {
				ignore_errors = true,
			})
		end)

		if ok then
			vim.schedule(finish)
      return
		end

		if autocmd then
			pcall(vim.api.nvim_del_autocmd, autocmd)
		end

		cb(nil)
	end, 1)()

	a.util.scheduler()

	if token and token.cancelled then
		buffer_pool.discard(bufnr, created)
		return nil
	end

	if not diagnostics then
		log:debug(function()
			return string.format("lint failed linter=%s path=%s", linter_name, path)
		end)
		buffer_pool.discard(bufnr, created)
		return nil
	end

	vim.diagnostic.set(namespace, bufnr, diagnostics)
	buffer_pool.retain(bufnr)

	return {
		path = path,
		diagnostics = diagnostics,
	}
end

return M
