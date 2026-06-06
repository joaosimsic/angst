{ pkgs, userConfig, ... }:

{
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
}
