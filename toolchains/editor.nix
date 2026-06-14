{ pkgs, ... }:

let
  tools = with pkgs; [ fd ripgrep ];
  runtime = with pkgs; [ tree-sitter ];
in {
  home.packages = tools ++ runtime;
}
