{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ odin ];
  lsp = with pkgs; [ ols ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-odin ];
  editor.lsp.ols = {
    command = [ "ols" ];
    extensions = [ ".odin" ];
  };
}
