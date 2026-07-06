local M = {}

M.setup = function(logger)
	local progress = require("backend.engines.lsp.progress")
	local inlay_hints = require("backend.engines.lsp.inlay_hints")
	local AdapterScanner = require("backend.shared.AdapterScanner")
	local LspHydra = require("backend.engines.lsp.hydra")
	local lsp_keys = require("backend.engines.lsp.keys")

	progress.setup_handler(logger)

	local group = vim.api.nvim_create_augroup("LspLifecycle", { clear = true })

	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		callback = function(event)
			local filetype = vim.bo[event.buf].filetype

			if AdapterScanner:supports_filetype("lsp", filetype) then
				LspHydra.create_diagnostics(event.buf)
			end
		end,
	})

	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(event)
			local bufnr = event.buf
			local client_id = event.data.client_id

			lsp_keys.setup(bufnr)

			local client = vim.lsp.get_client_by_id(client_id)

			if client and client:supports_method("textDocument/documentColor") and vim.lsp.color then
				vim.lsp.color.enable(false, { bufnr = bufnr })
			end

			if inlay_hints.try_enable(client, bufnr) then
				if logger then
					logger:debug(function()
						return string.format("inlayHint enabled for bufnr=%d client=%s", bufnr, client.name)
					end)
				end

				inlay_hints.setup_polling(client, bufnr, logger)
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

				inlay_hints.setup_retry(client, bufnr, logger)
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

			if logger and client then
				progress.start_fallback_timer(client, logger)
			end
		end,
	})

	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(event)
			local bufnr = event.buf

			inlay_hints.cleanup(bufnr)
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
