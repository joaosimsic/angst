{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [
    chez
    guile
  ];
  treesitter = with pkgs.tree-sitter-grammars; [
    tree-sitter-scheme
  ];
}
