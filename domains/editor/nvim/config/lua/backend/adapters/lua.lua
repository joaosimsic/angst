---@type Adapter

local ConfigPath = require("common.ConfigPath")

local function workspace_library()
	return ConfigPath.filter(vim.api.nvim_get_runtime_file("", true))
end

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
				library = workspace_library(),
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
	compiler = "lua",
	compiler_cmd = { "lua", "$FILE" },
}
