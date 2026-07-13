{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ taplo ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-toml ];
}
