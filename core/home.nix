{ config, pkgs, userConfig, ... }:

{
  programs.home-manager.enable = true;

  home.username = userConfig.username;
  home.homeDirectory = userConfig.homeDirectory;
  home.stateVersion = "24.05";

  fonts.fontconfig.enable = true;

  domains.shell.nushell.enable = true;
  domains.terminal.ghostty.enable = true;
  domains.terminal.zellij.enable = true;
}
