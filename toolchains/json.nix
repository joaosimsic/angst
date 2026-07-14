{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  lsp = [ pkgs.vscode-langservers-extracted ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-json ];
}
