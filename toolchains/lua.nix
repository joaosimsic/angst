{ pkgs, ... }:

let
  runtime = with pkgs; [ lua51Packages.luarocks ];
  lsp = with pkgs; [ lua-language-server ];
  formatter = with pkgs; [ stylua ];
in {
  home.packages = runtime ++ lsp ++ formatter;
}
