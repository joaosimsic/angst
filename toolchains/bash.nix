{ pkgs, ... }:

let
  lsp = with pkgs; [ bash-language-server ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-bash ];
in {
  home.packages = lsp;
  toolchains.treesitterGrammars = treesitter;
}
