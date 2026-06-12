{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nodePackages.vscode-langservers-extracted
    vue-language-server
    angular-language-server
    prisma-language-server
  ];
}
