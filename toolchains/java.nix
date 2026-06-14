{ pkgs, ... }:

let
  runtime = with pkgs; [ jdk21 ];
  lsp = with pkgs; [ jdt-language-server ];
  formatter = with pkgs; [ google-java-format ];
in {
  home.packages = runtime ++ lsp ++ formatter;
}
