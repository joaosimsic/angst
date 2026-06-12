{ pkgs, ... }:

{
  home.packages = with pkgs; [
    roslyn-ls
  ];
}
