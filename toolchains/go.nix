{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gopls
    gofumpt
    gotools
    golangci-lint
  ];
}
