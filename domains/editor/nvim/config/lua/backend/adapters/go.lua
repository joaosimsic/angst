return {
  filetypes = { "go" },
  lsp_server = "gopls",
  formatter = "goimports",
  linter = "golangci-lint",
  treesitter = "go",
  lsp_settings = {
    gopls = { staticcheck = true },
  },
}


