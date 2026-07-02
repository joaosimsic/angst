local AdapterScanner = require("backend.shared.AdapterScanner")

local M = {}

M.setup = function()
	local capabilities = vim.deepcopy(require("backend.engines.completion.config").capabilities())
	capabilities.experimental = capabilities.experimental or {}
	capabilities.experimental.serverStatusNotification = true

	local active_servers = AdapterScanner:by_tool("lsp")

	for server_name, server_opts in pairs(active_servers) do
		local existing_config = vim.lsp.config[server_name] or {}

		local cmd = server_opts.cmd
		if type(cmd) == "function" then
			cmd = cmd()
		end

		if not cmd then
			goto continue
		end

		local config = {
			cmd = cmd,
			capabilities = capabilities,
			filetypes = server_opts.filetypes or existing_config.filetypes,
		}

		local final_config = vim.tbl_deep_extend("force", existing_config, config, server_opts)

		final_config.cmd = cmd

		vim.lsp.config(server_name, final_config)
		vim.lsp.enable(server_name)

		::continue::
	end
end

return M
