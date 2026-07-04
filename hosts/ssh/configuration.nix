{ config, pkgs, inputs, hostname, ... }:

{
  imports = [
    ./hardware.nix
  ];

  networking.hostName = hostname;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  services.fstrim.enable = true;

  zramSwap.enable = true;

  capabilities.network.enable = true;
  capabilities.ssh.enable = true;
  capabilities.ssh.server.enable = true;
  capabilities.git.enable = true;
  capabilities.search.enable = true;
  capabilities.monitoring.enable = true;
  capabilities.container.enable = true;
}
