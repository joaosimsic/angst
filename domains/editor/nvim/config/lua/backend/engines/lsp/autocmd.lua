local M = {}

local client_attach_time = {}

---@param logger Logger
local function setup_progress_logger(logger)
	vim.lsp.handlers["$/progress"] = function(_, result, ctx)
		if not result or not result.value then
			return
		end

		local client = vim.lsp.get_client_by_id(ctx.client_id)
		if not client then
			return
		end

		if result.value.kind == "begin" then
			client_attach_time[client.id] = client_attach_time[client.id] or vim.uv.now()
		elseif result.value.kind == "end" then
			if logger and client_attach_time[client.id] and not client._lsp_ready_logged then
				local elapsed = vim.uv.now() - client_attach_time[client.id]
				client._lsp_ready_logged = true
				logger:info(function()
					return string.format("%s ready after %dms", client.name, elapsed)
				end)
			end
		end
	end
end

---@param logger Logger
M.setup = function(logger)
	setup_progress_logger(logger)

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
					local logged_warning = false
					local function check_hints()
						if vim.b[bufnr].lsp_inlay_verified or not vim.b[bufnr].lsp_inlay_polling then
							return
						end

						if not logged_warning then
							logged_warning = true
							if logger then
								logger:info(function()
									return string.format(
										"inlayHint still waiting for bufnr=%d client=%s (server analyzing)",
										bufnr,
										client.name
									)
								end)
							end
						end

						local line_count = vim.api.nvim_buf_line_count(bufnr)
						vim.lsp.buf_request(bufnr, "textDocument/inlayHint", {
							textDocument = { uri = vim.uri_from_bufnr(bufnr) },
							range = {
								start = { line = 0, character = 0 },
								["end"] = { line = line_count - 1, character = 9999 },
							},
						}, function(err, result)
							if err then
								return
							end
							if vim.b[bufnr].lsp_inlay_verified then
								return
							end
							if result and #result > 0 then
								vim.b[bufnr].lsp_inlay_verified = true
								vim.b[bufnr].lsp_inlay_polling = nil

								if logger then
									logger:info(function()
										return string.format(
											"inlayHint verified for bufnr=%d client=%s",
											bufnr,
											client.name
										)
									end)
								end

								if vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }) then
									vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
									vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })

									if logger then
										logger:info(function()
											return string.format(
												"inlayHint refreshed for bufnr=%d client=%s",
												bufnr,
												client.name
											)
										end)
									end
								end
							end
						end)
					end
					vim.defer_fn(check_hints, 1000)
					vim.defer_fn(check_hints, 2000)
					vim.defer_fn(check_hints, 4000)
					vim.defer_fn(check_hints, 8000)
					vim.defer_fn(check_hints, 16000)
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

			if logger and client and not client._lsp_fallback_timer then
				client._lsp_fallback_timer = vim.defer_fn(function()
					client._lsp_fallback_timer = nil
					if not client._lsp_ready_logged then
						local elapsed = vim.uv.now() - (client_attach_time[client.id] or vim.uv.now())
						logger:warn(function()
							return string.format(
								"%s not ready after %dms (no $/progress received). Inlay hints may still apply.",
								client.name,
								elapsed
							)
						end)
					end
				end, 15000)
			end
		end,
	})

	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(event)
			local bufnr = event.buf

			pcall(vim.lsp.inlay_hint.enable, false, { bufnr = bufnr })
			vim.b[bufnr].lsp_inlay_polling = nil

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
			vim.b[event.buf].lsp_inlay_polling = nil
		end,
	})
end

return M
