{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ gnumake ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-make ];
}
