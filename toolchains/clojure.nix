{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ clojure ];
  packageManager = with pkgs; [ leiningen ];
  lsp = with pkgs; [ clojure-lsp ];
  linter = with pkgs; [ clj-kondo ];
  formatter = with pkgs; [ cljfmt ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-clojure ];
}
