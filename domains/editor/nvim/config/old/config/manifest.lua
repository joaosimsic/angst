local M = {}

M.tools = {
	ai = "claudecode",

	servers = {
		"lua_ls",
		"clangd",
		"html",
		"ts_ls",
		"cssls",
		"gopls",
		"prismals",
		"intelephense",
		"vue_ls",
		"dockerls",
		"docker_compose_language_service",
		"bashls",
		"jdtls",
		"lemminx",
		"pyright",
		"terraformls",
		"rust_analyzer",
	},

	formatters = {
		lua = { "stylua" },
		python = { "black" },
		javascript = { "prettierd", "angularls" },
		javascriptreact = { "prettierd" },
		typescript = { "prettierd", "angularls" },
		typescriptreact = { "prettierd" },
		json = { "prettierd" },
		css = { "prettierd" },
		scss = { "prettierd" },
		html = { "prettierd" },
		blade = { "blade-formatter" },
		c = { "clang_format" },
		java = { "google-java-format" },
		go = { "goimports", "gofumpt" },
		rust = { "rustfmt" },
	},

	linters = {
		javascript = { "eslint_d" },
		typescript = { "eslint_d" },
		javascriptreact = { "eslint_d" },
		typescriptreact = { "eslint_d" },
		python = { "pylint" },
		go = { "golangcilint" },
	},
}

M.get_tools = function()
	local all = {}
	local seen = {}

	local mason_name_map = {
		["golangcilint"] = "golangci-lint",
		["clang_format"] = "clang-format",
	}

	for group_name, group_data in pairs(M.tools) do
		if type(group_data) == "table" then
			if group_name == "servers" then
				for _, item in ipairs(group_data) do
					local mason_name = mason_name_map[item] or item
					if not seen[mason_name] then
						table.insert(all, mason_name)
						seen[mason_name] = true
					end
				end
			else
				for _, items in pairs(group_data) do
					if type(items) == "table" then
						for _, item in ipairs(items) do
							local mason_name = mason_name_map[item] or item
							if not seen[mason_name] then
								table.insert(all, mason_name)
								seen[mason_name] = true
							end
						end
					end
				end
			end
		end
	end
	return all
end

return M
