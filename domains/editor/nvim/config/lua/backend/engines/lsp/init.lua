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
			local lsp_prov = lspconfig[server_name]
			local default_cmd = nil

			if lsp_prov and lsp_prov.document_config and lsp_prov.document_config.default_config then
				default_cmd = lsp_prov.document_config.default_config.cmd
			end

			local final_config = {
				capabilities = capabilities,
				cmd = default_cmd,
				filetypes = server_opts.filetypes,
				on_attach = function(_, bufnr)
					lsp_keys.setup(bufnr)
				end,
			}

			if server_opts.settings then
				final_config.settings = server_opts.settings
			end

			lspconfig[server_name].setup(final_config)
		end
	end,
}
