{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  lsp = with pkgs; [ lemminx ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-xml ];
  editor.lsp.xml = {
    command = [ "lemminx" ];
    extensions = [
      ".xml"
      ".xsd"
      ".xsl"
      ".xslt"
    ];
  };
}
