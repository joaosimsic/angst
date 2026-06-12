{ pkgs, ... }:

{
  home.packages = with pkgs; [
    lua-language-server
    stylua
    lua51Packages.luarocks
  ];
}
