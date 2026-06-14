{ pkgs, ... }:

let
  runtime = with pkgs; [ python3 ];
  lsp = with pkgs; [ pyright ];
  formatter = with pkgs; [ black ];
  linter = with pkgs; [ pylint ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-python ];
in {
  home.packages = runtime ++ lsp ++ formatter ++ linter;
  toolchains.treesitterGrammars = treesitter;
}
