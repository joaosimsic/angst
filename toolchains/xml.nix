{ pkgs, ... }:

let
  lsp = with pkgs; [ lemminx ];
in {
  home.packages = lsp;
}
