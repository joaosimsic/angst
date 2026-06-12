{ pkgs, ... }:

{
  home.packages = with pkgs; [
    dockerfile-language-server
    docker-compose-language-service
  ];
}
