{ pkgs, ... }:

let
  lsp = with pkgs; [ gopls ];
  formatter = with pkgs; [ gofumpt ];
  tools = with pkgs; [ gotools ];
  linter = with pkgs; [ golangci-lint ];
in {
  home.packages = lsp ++ formatter ++ tools ++ linter;
}
