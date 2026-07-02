{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ jdk21 ];
  packageManager = with pkgs; [ maven ];
  lsp = with pkgs; [ jdt-language-server ];
  linter = with pkgs; [ checkstyle ];
  formatter = with pkgs; [ google-java-format ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-java ];
}
