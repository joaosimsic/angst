{ pkgs, hostname, ... }:

{
  imports = [
    ./hardware.nix
    ../../common/capabilities.nix
    ../../lib/virtualisation
  ];

  networking.hostName = hostname;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  capabilities.audio.enable = true;
  capabilities.graphical.enable = true;
  capabilities.ssh.enable = true;
  capabilities.clipboard.enable = true;
}
