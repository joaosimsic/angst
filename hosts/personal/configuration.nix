{ config, pkgs, inputs, hostname, capabilities, ... }:

{
  imports = [
    ./hardware.nix

    capabilities.audio
    capabilities.network
    capabilities.container
    capabilities.git
  ];

  networking.hostName = hostname;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "amd_pstate=active" ];

  boot.initrd.kernelModules = [ "amdgpu" ];

  services.xserver.videoDrivers = [ "amdgpu" ];
  services.fstrim.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [ rocmPackages.clr.icd ];
  };

  hardware.cpu.amd.updateMicrocode = true;

  zramSwap.enable = true;
}
