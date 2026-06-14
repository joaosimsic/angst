{ pkgs, ... }:

let
  runtime = with pkgs; [ gcc ];
  tools = with pkgs; [ clang-tools ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-c tree-sitter-cpp ];
in {
  home.packages = runtime ++ tools;
  toolchains.treesitterGrammars = treesitter;
}
