{ lib, userConfig, ... }:

{
  imports = [
    ./font.nix
    ./treesitter.nix
    ../domains/domain-config.nix
  ];

  programs.home-manager.enable = true;

  home.username = lib.mkDefault userConfig.username;
  home.homeDirectory = lib.mkDefault userConfig.homeDirectory;
  home.stateVersion = "24.05";

  fonts.fontconfig.enable = true;
}
