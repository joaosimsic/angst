{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  lsp = with pkgs; [ bash-language-server ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-bash ];
  linter = with pkgs; [ shellcheck ];
  formatter = with pkgs; [ shfmt ];
}
