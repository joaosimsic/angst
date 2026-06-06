{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    nushell
    starship
  ];
}
