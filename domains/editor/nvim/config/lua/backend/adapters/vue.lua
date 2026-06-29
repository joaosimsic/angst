---@type Adapter
return {
	filetypes = { "vue" },
	lsp = "volar",
	lsp_cmd = { "vue-language-server", "--stdio" },
	treesitter = "vue",
	lsp_settings = {
		vue = {
			inlayHints = {
				destructuredProps = true,
				inlineHandlerLeading = true,
				missingProps = true,
				optionsWrapper = true,
				vBindShorthand = true,
			},
		},
	},
}
