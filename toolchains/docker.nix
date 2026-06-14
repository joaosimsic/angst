{ pkgs, ... }:

let
  lsp = with pkgs; [
    dockerfile-language-server
    docker-compose-language-service
  ];
  tools = with pkgs; [ lazydocker ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-dockerfile ];
in {
  home.packages = lsp ++ tools;
  toolchains.treesitterGrammars = treesitter;
}
