---@type Adapter
return {
	filetypes = { "java" },
	lsp = "jdtls",
	lsp_cmd = { "jdtls" },
	treesitter = "java",
	lsp_settings = {
		java = {
			inlayHints = {
				parameterNames = { enabled = "all" },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = true },
			},
		},
	},
}
