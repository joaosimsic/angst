---@type Adapter
return {
	filetypes = { "lua" },
	lsp = "lua_ls",
	lsp_cmd = { "lua-language-server" },
	formatter = "stylua",
	treesitter = "lua",

	lsp_settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
				pathStrict = true,
			},
			diagnostics = { enable = true, globals = { "vim" } },
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
