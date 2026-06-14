{ pkgs, ... }:

let
  lsp = with pkgs; [ intelephense ];
  formatter = with pkgs; [ blade-formatter ];
in {
  home.packages = lsp ++ formatter;
}
