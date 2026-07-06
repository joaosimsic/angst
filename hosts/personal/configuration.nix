{ config, pkgs, inputs, hostname, ... }:

{
  imports = [
    ./hardware.nix
    ../../common/capabilities.nix
    ../../lib/virtualisation
  ];

  networking.hostName = hostname;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "amd_pstate=active" ];

  boot.initrd.kernelModules = [ "amdgpu" ];

  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [ rocmPackages.clr.icd ];
  };

  hardware.cpu.amd.updateMicrocode = true;

  capabilities.audio.enable = true;
  capabilities.graphical.enable = true;
  capabilities.ssh.enable = true;
  capabilities.clipboard.enable = true;
}
