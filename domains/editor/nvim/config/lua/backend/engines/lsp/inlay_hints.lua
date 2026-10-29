local M = {}

function M.try_enable(client, bufnr)
	if client:supports_method("textDocument/inlayHint") then
		vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
		return true
	end
	return false
end

function M.setup_polling(client, bufnr, logger)
	if vim.b[bufnr].lsp_inlay_verified or vim.b[bufnr].lsp_inlay_polling then
		return
	end

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
						return string.format("inlayHint verified for bufnr=%d client=%s", bufnr, client.name)
					end)
				end

				if vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }) then
					vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
					vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })

					if logger then
						logger:info(function()
							return string.format("inlayHint refreshed for bufnr=%d client=%s", bufnr, client.name)
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

function M.setup_retry(client, bufnr, logger)
	vim.api.nvim_create_autocmd("LspNotify", {
		buffer = bufnr,
		once = true,
		callback = function()
			if M.try_enable(client, bufnr) and logger then
				logger:debug(function()
					return string.format("delayed inlayHint enable succeeded for bufnr=%d", bufnr)
				end)
			end
		end,
	})
end

function M.cleanup(bufnr)
	pcall(vim.lsp.inlay_hint.enable, false, { bufnr = bufnr })
	vim.b[bufnr].lsp_inlay_polling = nil
end

return M
