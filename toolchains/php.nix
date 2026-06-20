{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;

  phpPkgs = import pkgs.path {
    system = pkgs.stdenv.hostPlatform.system;
    
    config = {
      allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "intelephense"
      ];
    };
  };
in
mkToolchain {
  runtime = with phpPkgs; [
    php
    phpPackages.composer
  ];

  lsp = with phpPkgs; [
    intelephense
  ];

  formatter = with phpPkgs; [
    blade-formatter
  ];

  treesitter = with pkgs.tree-sitter-grammars; [
    tree-sitter-php
  ];
}
