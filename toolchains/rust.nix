{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ rustc ];
  packageManager = with pkgs; [ cargo ];
  lsp = with pkgs; [ rust-analyzer ];
  linter = with pkgs; [ clippy ];
  formatter = with pkgs; [ rustfmt ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-rust ];
}
