{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  lsp = with pkgs; [ vscode-langservers-extracted ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-css ];
  editor.lsp.css = {
    command = [
      "vscode-css-language-server"
      "--stdio"
    ];
    extensions = [
      ".css"
      ".scss"
      ".less"
    ];
  };
}
