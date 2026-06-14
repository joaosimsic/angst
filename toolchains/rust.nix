{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ cargo rustc ];
  lsp = with pkgs; [ rust-analyzer ];
  formatter = with pkgs; [ rustfmt ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-rust ];
}
