{ config, lib, pkgs, ... }:

let
  cfg = config.domains.editor.nvim;
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

      extraPackages = with pkgs; [
        fd
        kubectl
        lazydocker
        lazygit
        ripgrep
      ];
    };
  };
}
