{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [
    php
  ];
  packageManager = with pkgs; [
    phpPackages.composer
  ];

  lsp = with pkgs; [
    phpactor
    phpstan
  ];

  formatter = with pkgs; [
    phpPackages.php-cs-fixer
  ];

  treesitter = with pkgs.tree-sitter-grammars; [
    tree-sitter-php
  ];
}
