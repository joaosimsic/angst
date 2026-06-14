{ pkgs, ... }:

let
  lsp = with pkgs; [ nil ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-nix ];
in {
  home.packages = lsp;
  toolchains.treesitterGrammars = treesitter;
}
