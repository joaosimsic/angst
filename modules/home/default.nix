{ lib, userConfig, ... }:

{
  imports = [
    ./treesitter.nix
    ./login-shell.nix
  ];

  programs.home-manager.enable = true;

  home = {
    username = lib.mkDefault userConfig.username;
    homeDirectory = lib.mkDefault userConfig.homeDirectory;
    stateVersion = "24.05";
  };

  fonts.fontconfig.enable = true;
}
