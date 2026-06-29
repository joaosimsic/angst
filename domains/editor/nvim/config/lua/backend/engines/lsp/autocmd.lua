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
			if vim.b[event.buf].doktor_managed then
				return
			end

			local lsp_keys = require("backend.engines.lsp.keys")
			lsp_keys.setup(event.buf)

			local client = vim.lsp.get_client_by_id(event.data.client_id)

			if client and client:supports_method("textDocument/documentColor") then
				vim.lsp.document_color.enable(false, { bufnr = event.buf })
			end

			if client and client:supports_method("textDocument/inlayHint") then
				vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
			end

			vim.api.nvim_exec_autocmds("User", {
				pattern = vim.bo[event.buf].filetype,
				data = {
					bufnr = event.buf,
					client_id = event.data.client_id,
					filetype = vim.bo[event.buf].filetype,
					root_dir = client and client.config and client.config.root_dir or nil,
				},
			})
		end,
	})

	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(event)
			pcall(vim.lsp.inlay_hint.enable, false, { bufnr = event.buf })

			local lsp_keys = require("backend.engines.lsp.keys")
			lsp_keys.purge(event.buf)

			local hydra_instance = vim.b[event.buf].diagnostic_hydra

			if hydra_instance then
				hydra_instance:purge()
				vim.b[event.buf].diagnostic_hydra = nil
			end
		end,
	})
end

return M
