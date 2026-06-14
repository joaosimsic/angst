{ pkgs, ... }:

let
  runtime = with pkgs; [ cargo rustc ];
  lsp = with pkgs; [ rust-analyzer ];
  formatter = with pkgs; [ rustfmt ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-rust ];
in {
  home.packages = runtime ++ lsp ++ formatter;
  toolchains.treesitterGrammars = treesitter;
}
