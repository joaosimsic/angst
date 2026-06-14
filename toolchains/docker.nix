{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  lsp = with pkgs; [
    dockerfile-language-server
    docker-compose-language-service
  ];
  tools = with pkgs; [ lazydocker ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-dockerfile ];
}
