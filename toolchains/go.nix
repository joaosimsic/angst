{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ go ];
  lsp = with pkgs; [ gopls ];
  formatter = with pkgs; [ gofumpt ];
  tools = with pkgs; [ gotools ];
  linter = with pkgs; [ golangci-lint ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-go ];
}
