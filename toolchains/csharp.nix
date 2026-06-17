{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  lsp = with pkgs; [ roslyn-ls ];
  formatter = with pkgs; [ csharpier ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-c-sharp tree-sitter-razor ];
}
