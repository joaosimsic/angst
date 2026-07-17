---@type Adapter
return {
	filetypes = { "markdown", "markdown.mdx" },
	lsp = "marksman",
	lsp_cmd = { "marksman" },
	formatter = "mdformat",
	treesitter = { "markdown", "markdown-inline" },
}
