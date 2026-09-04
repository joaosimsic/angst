{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ rustc ];
  packageManager = with pkgs; [ cargo ];
  lsp = with pkgs; [ rust-analyzer ];
  linter = with pkgs; [ clippy ];
  formatter = with pkgs; [ rustfmt ];
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
