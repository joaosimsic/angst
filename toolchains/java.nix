{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ jdk21 ];
  lsp = with pkgs; [ jdt-language-server ];
  formatter = with pkgs; [ google-java-format ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-java ];
}
