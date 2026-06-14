{ pkgs, ... }:

let
  lsp = with pkgs; [ intelephense ];
  formatter = with pkgs; [ blade-formatter ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-php ];
in {
  home.packages = lsp ++ formatter;
  toolchains.treesitterGrammars = treesitter;
}
