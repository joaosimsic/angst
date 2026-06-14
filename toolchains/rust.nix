{ pkgs, ... }:

let
  runtime = with pkgs; [ cargo rustc ];
  lsp = with pkgs; [ rust-analyzer ];
  formatter = with pkgs; [ rustfmt ];
in {
  home.packages = runtime ++ lsp ++ formatter;
}
