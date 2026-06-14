{ pkgs, ... }:

let
  runtime = with pkgs; [ nodejs bun ];
  lsp = with pkgs; [
    typescript-language-server
    vscode-langservers-extracted
    vue-language-server
    angular-language-server
    prisma-language-server
  ];
  formatter = with pkgs; [ prettierd ];
  linter = with pkgs; [ eslint_d ];
in {
  home.packages = runtime ++ lsp ++ formatter ++ linter;
}
