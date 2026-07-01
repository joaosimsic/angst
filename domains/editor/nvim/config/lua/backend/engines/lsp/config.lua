local Logger = require("common.Logger")
local AdapterScanner = require("backend.shared.AdapterScanner")

local logger = Logger.new("LSPCFG")

local M = {}

M.setup = function()
	local capabilities = vim.deepcopy(require("backend.engines.completion.config").capabilities())

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

		if server_opts.settings then
			logger:info(function()
				return "applied settings for '" .. server_name .. "': " .. vim.inspect(server_opts.settings)
			end)
		else
			logger:warn(function()
				return "no settings found for '" .. server_name .. "' — inlay hints may not work"
			end)
		end

		::continue::
	end
end

return M
