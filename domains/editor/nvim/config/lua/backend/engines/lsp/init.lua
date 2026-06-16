return {
	"neovim/nvim-lspconfig",
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
	},
	config = function()
		local lspconfig = require("lspconfig")
		local capabilities = require("cmp_nvim_lsp").default_capabilities()

		local lsp_keys = require("backend.engines.lsp.keys")
		local scan_adapters = require("backend.shared.scan_adapters")

		local active_servers = scan_adapters("lsp", {})

		for server_name, server_opts in pairs(active_servers) do
			local config = {
				capabilities = capabilities,
				filetypes = server_opts.filetypes,
				on_attach = function(_, bufnr)
					lsp_keys.setup(bufnr)
				end,
			}

			if server_opts.settings then
				config.settings = {
					[server_name] = server_opts.settings,
				}
			end

			if server_opts.cmd then
				config.cmd = server_opts.cmd
			end

			lspconfig[server_name].setup(config)
		end
	end,
}
