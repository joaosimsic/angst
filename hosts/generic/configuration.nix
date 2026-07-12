{ pkgs, hostname, lib, ... }:

{
  imports = [
    ./hardware.nix
    ../../common/capabilities.nix
    ../../lib/virtualisation
  ];

  networking.hostName = hostname;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  console.keyMap = lib.mkForce "us";
  services.xserver.xkb.layout = lib.mkForce "us";
  services.xserver.xkb.variant = lib.mkForce "";
  time.timeZone = lib.mkForce "UTC";

  capabilities.audio.enable = true;
  capabilities.graphical.enable = true;
  capabilities.ssh.enable = true;
  capabilities.clipboard.enable = true;
}
