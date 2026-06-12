{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vscode-langservers-extracted
    vue-language-server
    angular-language-server
    prisma-language-server
  ];
}
