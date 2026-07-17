{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ nodejs ];
  lsp = with pkgs; [ marksman ];
  formatter = with pkgs; [ mdformat ];
  treesitter = with pkgs.tree-sitter-grammars; [
    tree-sitter-markdown
    tree-sitter-markdown-inline
  ];
}
