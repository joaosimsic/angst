{ pkgs, ... }:

{
  home.packages = with pkgs; [
    lemminx
  ];
}
