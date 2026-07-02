local M = {}

local inlay_timers = {}

local function cleanup_timer(bufnr)
	local timer = inlay_timers[bufnr]
	if timer then
		timer:stop()
		inlay_timers[bufnr] = nil
	end
	vim.b[bufnr].lsp_inlay_polling = nil
	vim.b[bufnr].lsp_inlay_verified = nil
end

---@param logger Logger
M.setup = function(logger)
	local group = vim.api.nvim_create_augroup("LspLifecycle", { clear = true })

	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		callback = function(event)
			local AdapterScanner = require("backend.shared.AdapterScanner")
			local filetype = vim.bo[event.buf].filetype

			if AdapterScanner:supports_filetype("lsp", filetype) then
				local LspHydra = require("backend.engines.lsp.hydra")
				LspHydra.create_diagnostics(event.buf)
			end
		end,
	})

	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(event)
			local bufnr = event.buf
			local client_id = event.data.client_id

			if vim.b[bufnr].doktor_managed then
				return
			end

			local lsp_keys = require("backend.engines.lsp.keys")
			lsp_keys.setup(bufnr)

			local client = vim.lsp.get_client_by_id(client_id)

			if client and client:supports_method("textDocument/documentColor") and vim.lsp.color then
				vim.lsp.color.enable(false, { bufnr = bufnr })
			end

			local function try_enable_hints()
				if client:supports_method("textDocument/inlayHint") then
					vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
					return true
				end
				return false
			end

			if try_enable_hints() then
				if logger then
					logger:debug(function()
						return string.format("inlayHint enabled for bufnr=%d client=%s", bufnr, client.name)
					end)
				end

				if vim.b[bufnr].lsp_inlay_verified then
					return
				end

				if not vim.b[bufnr].lsp_inlay_polling then
					vim.b[bufnr].lsp_inlay_polling = true
					local timer = vim.uv.new_timer()
					inlay_timers[bufnr] = timer
					local attempts = 0
					timer:start(1000, 1000, vim.schedule_wrap(function()
						attempts = attempts + 1
						if attempts > 5 then
							timer:stop()
							cleanup_timer(bufnr)
							return
						end

						if vim.b[bufnr].lsp_inlay_verified then
							timer:stop()
							cleanup_timer(bufnr)
							return
						end

						vim.lsp.buf_request(bufnr, "textDocument/inlayHint", {
							textDocument = { uri = vim.uri_from_bufnr(bufnr) },
							range = {
								start = { line = 0, character = 0 },
								["end"] = { line = 0, character = 0 },
							},
						}, function(err, result)
							if err then
								return
							end
							if result and #result > 0 then
								timer:stop()
								cleanup_timer(bufnr)
								vim.b[bufnr].lsp_inlay_verified = true

								if vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }) then
									vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
									vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
								end
							end
						end)
					end))
				end
			else
				if logger then
					logger:debug(function()
						return string.format(
							"inlayHint not yet supported for bufnr=%d client=%s, queuing LspNotify retry",
							bufnr,
							client.name
						)
					end)
				end
				vim.api.nvim_create_autocmd("LspNotify", {
					buffer = bufnr,
					once = true,
					callback = function()
						if try_enable_hints() and logger then
							logger:debug(function()
								return string.format("delayed inlayHint enable succeeded for bufnr=%d", bufnr)
							end)
						end
					end,
				})
			end

			vim.api.nvim_exec_autocmds("User", {
				pattern = vim.bo[bufnr].filetype,
				data = {
					bufnr = bufnr,
					client_id = client_id,
					filetype = vim.bo[bufnr].filetype,
					root_dir = client and client.config and client.config.root_dir or nil,
				},
			})
		end,
	})

	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(event)
			local bufnr = event.buf

			pcall(vim.lsp.inlay_hint.enable, false, { bufnr = bufnr })

			local lsp_keys = require("backend.engines.lsp.keys")
			lsp_keys.purge(bufnr)

			local hydra_instance = vim.b[bufnr].diagnostic_hydra

			if hydra_instance then
				hydra_instance:purge()
				vim.b[bufnr].diagnostic_hydra = nil
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufUnload", {
		group = group,
		callback = function(event)
			cleanup_timer(event.buf)
		end,
	})
end

return M
