{ pkgs, ... }:

let
  lsp = with pkgs; [ terraform-ls ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-hcl ];
in {
  home.packages = lsp;
  toolchains.treesitterGrammars = treesitter;
}
