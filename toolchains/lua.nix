{ pkgs, ... }:

let
  runtime = with pkgs; [ lua51Packages.luarocks ];
  lsp = with pkgs; [ lua-language-server ];
  formatter = with pkgs; [ stylua ];
  treesitter = with pkgs.tree-sitter-grammars; [ tree-sitter-lua ];
in {
  home.packages = runtime ++ lsp ++ formatter;
  toolchains.treesitterGrammars = treesitter;
}
