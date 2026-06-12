{ pkgs, ... }:

let
  treesitter = pkgs.vimPlugins.nvim-treesitter.passthru;
in
{
  home.packages = with pkgs; [
    fd
    ripgrep
    tree-sitter
  ];

  programs.neovim.extraPackages = [
    (treesitter.withPlugins [
      treesitter.parsers.php
      treesitter.parsers.html
      treesitter.parsers.typescript
      treesitter.parsers.angular
      treesitter.parsers.java
      treesitter.parsers.go
      treesitter.parsers.css
      treesitter.parsers.lua
      treesitter.parsers.json
      treesitter.parsers.python
      treesitter.parsers.c_sharp
      treesitter.parsers.razor
      treesitter.parsers.markdown
      treesitter.parsers.markdown_inline
    ])
  ];
}
