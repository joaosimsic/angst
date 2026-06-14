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
    enableDefaultConfig = false;

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        IdentityFile = "~/.ssh/id_ed25519";
      };

      "github.com" = {
        Host = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519";
        StrictHostKeyChecking = "accept-new";
      };
    };
  };
}
