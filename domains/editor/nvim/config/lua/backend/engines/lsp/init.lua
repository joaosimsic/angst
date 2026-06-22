return {
	"lsp-engine",
	virtual = true,
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local group = vim.api.nvim_create_augroup("LspAttach", { clear = true })

		vim.api.nvim_create_autocmd("LspAttach", {
			group = group,
			callback = function(event)
				local lsp_keys = require("backend.engines.lsp.keys")
				lsp_keys.setup(event.buf)
			end,
		})

		local capabilities = require("backend.engines.completion.config").capabilities()

		local AdapterScanner = require("backend.shared.AdapterScanner")
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

			if server_opts.settings then
				config.settings = server_opts.settings
			end

			local final_config = vim.tbl_deep_extend("force", existing_config, config)

			vim.lsp.config(server_name, final_config)
			vim.lsp.enable(server_name)

			::continue::
		end
	end,
}
