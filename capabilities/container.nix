{ config, lib, pkgs, userConfig, ... }:

let
  cfg = config.capabilities.container;
in
{
  options.capabilities.container = {
    enable = lib.mkEnableOption "Container runtimes via Docker and Podman";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    virtualisation.podman = {
      enable = true;
      dockerCompat = false;
      defaultNetwork.settings.dns_enabled = true;
    };

    users.users.${userConfig.username}.extraGroups = [ "docker" "podman" ];

    environment.systemPackages = with pkgs; [
      kubectl
    ];
  };
}
