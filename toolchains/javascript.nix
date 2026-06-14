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
  treesitter = with pkgs.tree-sitter-grammars; [
    tree-sitter-javascript
    tree-sitter-typescript
    tree-sitter-tsx
    tree-sitter-html
    tree-sitter-css
    tree-sitter-json
    tree-sitter-vue
  ];
in {
  home.packages = runtime ++ lsp ++ formatter ++ linter;
  toolchains.treesitterGrammars = treesitter;
}
