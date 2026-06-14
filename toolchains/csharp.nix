{ pkgs, ... }:

let
  lsp = with pkgs; [ roslyn-ls ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-c-sharp tree-sitter-razor ];
in {
  home.packages = lsp;
  toolchains.treesitterGrammars = treesitter;
}
