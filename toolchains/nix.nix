{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  lsp = with pkgs; [
    nil
    nixd
  ];
  formatter = with pkgs; [ nixfmt ];
  linter = with pkgs; [
    statix
    deadnix
  ];
  tools = with pkgs; [
    nix-output-monitor
    nix-tree
  ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-nix ];
}
