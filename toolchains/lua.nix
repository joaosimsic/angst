{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ lua51Packages.luarocks ];
  lsp = with pkgs; [ lua-language-server ];
  formatter = with pkgs; [ stylua ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-lua ];
}
