{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  linter = [ pkgs.editorconfig-checker ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-ini ];
}
