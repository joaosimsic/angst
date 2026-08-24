{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ ghc ];
  packageManager = with pkgs; [ cabal-install ];
  lsp = with pkgs; [ haskell-language-server ];
  formatter = with pkgs; [ fourmolu ];
  linter = with pkgs; [ hlint ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-haskell ];
}
