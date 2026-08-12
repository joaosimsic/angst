{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ just ];
  lsp = with pkgs; [ just-lsp ];
  formatter = with pkgs; [ just-formatter ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-just ];
}
