local M = {}

M.setup = function()
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

			if client and client:supports_method("textDocument/documentColor") then
				vim.lsp.document_color.enable(false, { bufnr = bufnr })
			end

			if client and client:supports_method("textDocument/inlayHint") then
				vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
				vim.defer_fn(function()
					if vim.api.nvim_buf_is_valid(bufnr) then
						vim.api.nvim__redraw({ flush = true })
					end
				end, 100)
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
end

return M
