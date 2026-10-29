---@type Adapter
return {
	filetypes = { "gowork" },
	lsp = "gopls",
	lsp_cmd = { "gopls", "-remote=unix;/run/user/1000/gopls.sock" },
	treesitter = "gowork",
}
