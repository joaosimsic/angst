{ pkgs, lib }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [ taplo ];
  lsp = with pkgs; [ taplo ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-toml ];
  editor.lsp.toml = {
    command = [
      "taplo"
      "lsp"
      "stdio"
    ];
    extensions = [ ".toml" ];
  };
}
