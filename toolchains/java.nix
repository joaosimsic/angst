{ pkgs, ... }:

let
  runtime = with pkgs; [ jdk21 ];
  lsp = with pkgs; [ jdt-language-server ];
  formatter = with pkgs; [ google-java-format ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-java ];
in {
  home.packages = runtime ++ lsp ++ formatter;
  toolchains.treesitterGrammars = treesitter;
}
