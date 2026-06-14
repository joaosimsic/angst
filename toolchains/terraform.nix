{ pkgs, ... }:

let
  lsp = with pkgs; [ terraform-ls ];
in {
  home.packages = lsp;
}
