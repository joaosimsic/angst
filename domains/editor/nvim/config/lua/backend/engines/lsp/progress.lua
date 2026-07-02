local M = {}

local client_attach_time = {}

function M.setup_handler(logger)
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

function M.start_fallback_timer(client, logger)
	if client._lsp_fallback_timer then
		return
	end

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

return M
