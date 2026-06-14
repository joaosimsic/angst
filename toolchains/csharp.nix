{ pkgs, ... }:

let
  lsp = with pkgs; [ roslyn-ls ];
in {
  home.packages = lsp;
}
