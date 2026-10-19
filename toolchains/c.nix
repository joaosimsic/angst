{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ gcc ];
  tools = with pkgs; [ clang-tools ];
  treesitter = with pkgs.tree-sitter-grammars; [
    tree-sitter-c
    tree-sitter-cpp
  ];
  editor.lsp.clangd = {
    command = [ "clangd" ];
    extensions = [
      ".c"
      ".h"
      ".cpp"
      ".hpp"
      ".cc"
      ".hh"
      ".cxx"
      ".hxx"
    ];
  };
}
