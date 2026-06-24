local M = {}

M.setup = function()
	local group = vim.api.nvim_create_augroup("LspLifecycle", { clear = true })

	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(event)
			local lsp_keys = require("backend.engines.lsp.keys")
			lsp_keys.setup(event.buf)

			local client = vim.lsp.get_client_by_id(event.data.client_id)

			if client and client:supports_method("textDocument/inlayHint") then
				vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
			end
		end,
	})

	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(event)
			vim.lsp.inlay_hint.enable(false, { bufnr = event.buf })

			local lsp_keys = require("backend.engines.lsp.keys")
			lsp_keys.purge(event.buf)
		end,
	})
end

return M
