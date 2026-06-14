{ pkgs, ... }:

let
  runtime = with pkgs; [ gcc ];
  tools = with pkgs; [ clang-tools ];
in {
  home.packages = runtime ++ tools;
}
