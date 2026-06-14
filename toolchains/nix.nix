{ pkgs, ... }:

let
  lsp = with pkgs; [ nil ];
in {
  home.packages = lsp;
}
