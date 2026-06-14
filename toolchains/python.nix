{ pkgs, ... }:

let
  runtime = with pkgs; [ python3 ];
  lsp = with pkgs; [ pyright ];
  formatter = with pkgs; [ black ];
  linter = with pkgs; [ pylint ];
in {
  home.packages = runtime ++ lsp ++ formatter ++ linter;
}
