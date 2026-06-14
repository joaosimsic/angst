{ config, pkgs, userConfig, ... }:

{
  imports = [ ./fontModule.nix ./domain-config.nix ./treesitter.nix ];

  programs.home-manager.enable = true;

  home.username = userConfig.username;
  home.homeDirectory = userConfig.homeDirectory;
  home.stateVersion = "24.05";

  fonts.fontconfig.enable = true;

  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";

    matchBlocks = {
      "github.com" = {
        host = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          StrictHostKeyChecking = "accept-new";
        };
      };
    };
  };
}
