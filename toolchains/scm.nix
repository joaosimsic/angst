{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  tools = with pkgs; [
    tree-sitter
  ];
  treesitter = with pkgs.tree-sitter-grammars; [
    tree-sitter-query
  ];
}
