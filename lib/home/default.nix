{ userConfig, ... }:

{
  imports = [
    ./font.nix
    ./treesitter.nix
    ./ssh.nix
    ../domains/domain-config.nix
  ];

  programs.home-manager.enable = true;

  home.username = userConfig.username;
  home.homeDirectory = userConfig.homeDirectory;
  home.stateVersion = "24.05";

  fonts.fontconfig.enable = true;
}
