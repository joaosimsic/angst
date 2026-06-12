{ pkgs, ... }:

{
  home.packages = with pkgs; [
    intelephense
    blade-formatter
  ];
}
