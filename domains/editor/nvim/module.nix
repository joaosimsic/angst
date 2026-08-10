{ config, lib, pkgs, ... }:

let
  cfg = config.domains.editor.nvim;
in
{
  config = lib.mkIf cfg.enable {
    home = {
      packages = [ pkgs.neovim ];

      sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };

      shellAliases = {
        vi = "nvim";
        vim = "nvim";
      };
    };
  };
}
