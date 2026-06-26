local a = require("plenary.async")
local uv = a.uv
local logging = require("backend.engines.doktor.logging")

local M = {}
local log = logging.for_module("lsp_bridge")

---@class LspDiagnosticsResult
---@field uri string
---@field diagnostics lsp.Diagnostic[]

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
---@param filetype string
---@return vim.lsp.Client[]
local function matching_clients(path, filetype)
	---@type vim.lsp.Client[]
	local clients = {}

	for _, client in ipairs(vim.lsp.get_clients()) do
		local filetypes = client.config and client.config["filetypes"]

		if not filetypes then
			goto continue
		end

		if not vim.tbl_contains(filetypes, filetype) then
			goto continue
		end

		local root = client.config and client.config.root_dir

		if not root or path:sub(1, #root) == root then
			clients[#clients + 1] = client
		end

		::continue::
	end

	return clients
end

---@param path string
---@param filetype string
---@param token? CancellationToken
---@return integer, boolean
local function create_hidden_buffer(path, filetype, token)
	if token and token.cancelled then
		return -1, false
	end

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

	if not created then
		vim.bo[bufnr].modified = false
		return bufnr, created
	end

	a.util.scheduler()
	if token and token.cancelled then
		return bufnr, created
	end

	local lines = read_lines(path)
	if lines then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	end

	vim.bo[bufnr].modified = false

	return bufnr, created
end

---@param bufnr integer
---@param created boolean
---@param attached_ids integer[]
local function cleanup_buffer(bufnr, created, attached_ids)
	if created and vim.api.nvim_buf_is_valid(bufnr) then
		pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
	end

	for _, client_id in ipairs(attached_ids) do
		pcall(vim.lsp.buf_detach_client, bufnr, client_id)
	end
end

---@async
---@param path string
---@param filetype string
---@param timeout_ms integer
---@param namespace integer
---@param token? CancellationToken
---@return LspDiagnosticsResult|nil
function M.fetch(path, filetype, timeout_ms, namespace, token)
	if token and token.cancelled then
		return nil
	end

	local clients = matching_clients(path, filetype)
	if #clients == 0 then
		log:debug(function()
			return string.format("no matching client path=%s ft=%s", path, filetype)
		end)
		return nil
	end

	local bufnr, created = create_hidden_buffer(path, filetype, token)
	if token and token.cancelled then
		cleanup_buffer(bufnr, created, {})
		return nil
	end

	local uri = vim.uri_from_fname(path)
	local attached_ids = {}

	for _, client in ipairs(clients) do
		pcall(vim.lsp.buf_attach_client, bufnr, client.id)
		attached_ids[#attached_ids + 1] = client.id
	end

	a.util.scheduler()
	if token and token.cancelled then
		cleanup_buffer(bufnr, created, attached_ids)
		return nil
	end

	---@type LspDiagnosticsResult|nil
	local result = a.wrap(function(cb)
		local completed = false
		local autocmd
		local timer

		local function finish(diagnostics)
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

			if diagnostics then
				vim.diagnostic.set(namespace, bufnr, diagnostics)
			end

			cleanup_buffer(bufnr, created, attached_ids)
			cb(diagnostics and {
				uri = uri,
				diagnostics = diagnostics,
			} or nil)
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

				finish(vim.diagnostic.get(bufnr))
				return true
			end,
		})

		timer = vim.uv.new_timer()

		if not timer then
			return finish(nil)
		end

		timer:start(timeout_ms, 0, function()
			vim.schedule(function()
				finish(nil)
			end)
		end)
	end, 1)()

	a.util.scheduler()
	if token and token.cancelled then
		return nil
	end

	return result
end

return M
