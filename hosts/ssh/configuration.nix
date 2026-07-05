{ config, pkgs, inputs, hostname, ... }:

{
  imports = [
    ./hardware.nix
    ../../common/capabilities.nix
  ];

  networking.hostName = hostname;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  capabilities.ssh.enable = true;
  capabilities.ssh.server.enable = true;
}
