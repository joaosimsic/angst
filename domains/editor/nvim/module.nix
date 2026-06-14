{ config, lib, pkgs, ... }:

let
  cfg = config.domains.editor.nvim;
  treesitter = pkgs.vimPlugins.nvim-treesitter.passthru;
in
{
  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withRuby = false;
      withPython3 = false;
      extraPackages = [
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
    };

    xdg.configFile."nvim/init.lua".enable = lib.mkForce false;
  };
}
