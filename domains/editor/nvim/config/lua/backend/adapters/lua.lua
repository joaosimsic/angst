---@type Adapter
return {
	filetypes = { "lua" },
	lsp = "lua_ls",
	lsp_cmd = { "lua-language-server" },
	formatter = "stylua",
	treesitter = "lua",
	doktor_resolver = {
		filetypes = { "lua" },
		resolve = function(token, _context_buf)
			if token:sub(1, 1) == "." then
				return nil
			end

			local lua_path = token:gsub("%.", "/")
			for entry in package.path:gmatch("[^;]+") do
				local candidate = entry:gsub("%?", lua_path)
				local stat = vim.uv.fs_stat(candidate)
				if stat and stat.type == "file" then
					return vim.uv.fs_realpath(candidate) or candidate
				end
			end
		end,
	},
	lsp_settings = {
		Lua = {
			diagnostics = { globals = { "vim" } },
			workspace = {
				library = vim.api.nvim_get_runtime_file("", true),
				checkThirdParty = false,
			},
			telemetry = { enable = false },
			hint = {
				enable = true,
				paramName = "All",
				paramType = true,
				setType = true,
				arrayIndex = "Auto",
				await = true,
				semicolon = "All",
			},
		},
	},
}
