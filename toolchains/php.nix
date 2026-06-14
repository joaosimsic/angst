{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  lsp = with pkgs; [ intelephense ];
  formatter = with pkgs; [ blade-formatter ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-php ];
}
