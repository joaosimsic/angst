{ pkgs, lib, ... }:

let
  inherit (import ../lib/toolchain.nix { inherit lib pkgs; }) mkToolchain;
in
mkToolchain {
  runtime = with pkgs; [
    nodejs
    bun
  ];
  lsp = [
    pkgs.typescript-language-server
    pkgs.vscode-langservers-extracted
    pkgs.vue-language-server
    pkgs.angular-language-server
    pkgs.prisma-language-server
  ];
  formatter = with pkgs; [ prettierd ];
  linter = with pkgs; [ eslint_d ];
  treesitter = with pkgs.tree-sitter-grammars; [
    tree-sitter-javascript
    tree-sitter-typescript
    tree-sitter-vue
  ];
}
