---@type Adapter
return {
	filetypes = { "terraform", "tf" },
	lsp = "terraformls",
	lsp_cmd = { "terraform-ls", "serve" },
	treesitter = "hcl",
}
