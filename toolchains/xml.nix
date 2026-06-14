{ pkgs, ... }:

let
  lsp = with pkgs; [ lemminx ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-xml ];
in {
  home.packages = lsp;
  toolchains.treesitterGrammars = treesitter;
}
