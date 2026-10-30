{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  lsp = with pkgs; [ vscode-langservers-extracted ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-html ];
  editor.lsp.html = {
    command = [
      "vscode-html-language-server"
      "--stdio"
    ];
    extensions = [ ".html" ];
  };
}
