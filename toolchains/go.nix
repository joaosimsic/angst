{ pkgs, ... }:

let
  lsp = with pkgs; [ gopls ];
  formatter = with pkgs; [ gofumpt ];
  tools = with pkgs; [ gotools ];
  linter = with pkgs; [ golangci-lint ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-go ];
in {
  home.packages = lsp ++ formatter ++ tools ++ linter;
  toolchains.treesitterGrammars = treesitter;
}
