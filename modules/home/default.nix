{ lib, userConfig, ... }:

{
  imports = [
    ./treesitter.nix
    ./login-shell.nix
    ./nix-ld-compat.nix
    ./nushell-bridge.nix
    ./clean-desktop-shadows.nix
  ];

  programs.home-manager.enable = true;

  home = {
    username = lib.mkDefault userConfig.username;
    homeDirectory = lib.mkDefault userConfig.homeDirectory;
    stateVersion = "24.05";
  };

  fonts.fontconfig.enable = true;
}
