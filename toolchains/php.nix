{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nodePackages.intelephense
    blade-formatter
  ];
}
