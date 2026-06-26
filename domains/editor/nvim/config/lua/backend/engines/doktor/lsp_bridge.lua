local M = {}
local logging = require("backend.engines.doktor.logging")
local log = logging.for_module("lsp_bridge")

---@class LspDiagnosticsResult
---@field uri string
---@field diagnostics lsp.Diagnostic[]

---@param path string
---@param filetype string
---@return vim.lsp.Client[]
local function matching_clients(path, filetype)
	local clients = {}
	local current_clients = vim.lsp.get_clients({ bufnr = 0 })
	for _, client in ipairs(current_clients) do
		local filetypes = client.config and client.config.filetypes
		if not filetypes or vim.tbl_contains(filetypes, filetype) then
			clients[#clients + 1] = client
		end
	end

	if #clients == 0 then
		for _, client in ipairs(vim.lsp.get_clients()) do
			local filetypes = client.config and client.config.filetypes
			if not filetypes or vim.tbl_contains(filetypes, filetype) then
				local root = client.config and client.config.root_dir
				if not root or path:sub(1, #root) == root then
					clients[#clients + 1] = client
				end
			end
		end
	end

	return clients
end

---@param path string
---@param filetype string
---@return integer, boolean
local function create_hidden_buffer(path, filetype)
	local existing = vim.fn.bufnr(path)
	local bufnr = existing ~= -1 and existing or vim.api.nvim_create_buf(false, true)
	local created = existing == -1
	if created then
		vim.api.nvim_buf_set_name(bufnr, path)
		vim.b[bufnr].doktor_managed = true
	end
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].buftype = ""
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = filetype

	local ok, lines = pcall(vim.fn.readfile, path)
	if ok and created then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	end

	vim.bo[bufnr].modified = false
	return bufnr, created
end

---@param path string
---@param filetype string
---@param timeout_ms integer
---@param namespace integer
---@param done fun(result: LspDiagnosticsResult|nil)
function M.fetch(path, filetype, timeout_ms, namespace, done)
	local clients = matching_clients(path, filetype)
	if #clients == 0 then
		log:debug(function()
			return string.format("no matching client path=%s ft=%s", path, filetype)
		end)
		done(nil)
		return
	end

	local bufnr = create_hidden_buffer(path, filetype)
	local uri = vim.uri_from_fname(path)
	local completed = false
	local autocmd
	local timer

	local function finish(result)
		if completed then
			return
		end

		completed = true
		if autocmd then
			pcall(vim.api.nvim_del_autocmd, autocmd)
		end
		if timer then
			timer:stop()
			timer:close()
		end

		if result then
			vim.diagnostic.set(namespace, bufnr, result.diagnostics or {})
		end

		done(result)
	end

	for _, client in ipairs(clients) do
		pcall(vim.lsp.buf_attach_client, bufnr, client.id)
	end

	autocmd = vim.api.nvim_create_autocmd({ "LspNotify", "DiagnosticChanged", "LspDetach" }, {
		buffer = bufnr,
		callback = function(args)
			if args.event == "LspDetach" then
				finish(nil)
				return true
			end

			if args.event == "LspNotify" then
				local data = args.data or {}
				if data.method ~= "textDocument/publishDiagnostics" then
					return
				end
			end

			vim.defer_fn(function()
				finish({
					uri = uri,
					diagnostics = vim.diagnostic.get(bufnr),
				})
			end, 10)
			return true
		end,
	})

	timer = vim.uv.new_timer()
	timer:start(timeout_ms, 0, function()
		vim.schedule(function()
			finish(nil)
		end)
	end)
end

return M
