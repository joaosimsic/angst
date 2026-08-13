{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ yq ];
  lsp = with pkgs; [ yaml-language-server ];
  formatter = with pkgs; [ yamlfmt ];
  linter = with pkgs; [ yamllint ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-yaml ];
}
