{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ python3 ];
  lsp = with pkgs; [ pyright ];
  formatter = with pkgs; [ black ];
  linter = with pkgs; [ pylint ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-python ];
}
