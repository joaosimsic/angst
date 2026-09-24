{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-rust ];
  editor.lsp.rust = {
    command = [ "rust-analyzer" ];
    extensions = [ ".rs" ];
    initialization = {
      "rust-analyzer".check.command = "clippy";
      "rust-analyzer".inlayHints.chainingHints.enable = true;
      "rust-analyzer".inlayHints.parameterHints.enable = true;
      "rust-analyzer".inlayHints.typeHints.enable = true;
    };
  };
}
