{ pkgs, ... }:

let
  lsp = with pkgs; [
    dockerfile-language-server
    docker-compose-language-service
  ];
  tools = with pkgs; [ lazydocker ];
in {
  home.packages = lsp ++ tools;
}
