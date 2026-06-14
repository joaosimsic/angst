{ pkgs, ... }:

let
  lsp = with pkgs; [ bash-language-server ];
in {
  home.packages = lsp;
}
