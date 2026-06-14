{ config, lib, pkgs, ... }:

let
  cfg = config.domains.editor.nvim;
  treesitter = pkgs.tree-sitter.withPlugins (_: config.toolchains.treesitterGrammars);
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
      extraPackages = [ treesitter ];
    };

    xdg.configFile."nvim/init.lua".enable = lib.mkForce false;
  };
}
