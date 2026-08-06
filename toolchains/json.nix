{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  lsp = [ pkgs.vscode-langservers-extracted ];
  formatter = [ pkgs.fixjson ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-json ];
}
