{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-css ];
}
