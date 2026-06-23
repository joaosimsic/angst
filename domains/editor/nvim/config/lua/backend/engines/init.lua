return {
	"lsp-engine",
	virtual = true,
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local function refresh_inlay_hints(client, bufnr)
			if client.name ~= "phpactor" then
				return
			end

			for _, delay in ipairs({ 500, 1500, 3000 }) do
				vim.defer_fn(function()
					if not vim.api.nvim_buf_is_valid(bufnr) or (client.is_stopped and client:is_stopped()) then
						return
					end

					vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
					vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
				end, delay)
			end
		end

		local group = vim.api.nvim_create_augroup("LspAttach", { clear = true })

		vim.api.nvim_create_autocmd("LspAttach", {
			group = group,
			callback = function(event)
				local lsp_keys = require("backend.engines.lsp.keys")
				lsp_keys.setup(event.buf)

				local client = vim.lsp.get_client_by_id(event.data.client_id)

				if client and client:supports_method("textDocument/inlayHint") then
					vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
					refresh_inlay_hints(client, event.buf)
				end
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

			if server_opts.init_options then
				config.init_options = server_opts.init_options
			end

			if server_opts.root_markers then
				config.root_markers = server_opts.root_markers
			end

			if server_opts.root_dir then
				config.root_dir = server_opts.root_dir
			end

			local final_config = vim.tbl_deep_extend("force", existing_config, config)

			vim.lsp.config(server_name, final_config)
			vim.lsp.enable(server_name)

			::continue::
		end
	end,
}
