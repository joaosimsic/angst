{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  lsp = with pkgs; [ roslyn-ls ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-c-sharp tree-sitter-razor ];
}
