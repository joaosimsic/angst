return {
  filetypes = { "go" },
  lsp = "gopls",
  formatter = "goimports",
  linter = "golangci-lint",
  treesitter = "go",
  lsp_settings = {
    gopls = { staticcheck = true },
  },
}


