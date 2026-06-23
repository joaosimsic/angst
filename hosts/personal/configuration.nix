{ config, pkgs, inputs, hostname, ... }:

{
  imports = [
    ./hardware.nix
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

  capabilities.audio.enable = true;
  capabilities.graphical.enable = true;
  capabilities.network.enable = true;
  capabilities.container.enable = true;
  capabilities.git.enable = true;
  capabilities.search.enable = true;
  capabilities.ssh.enable = true;
  capabilities.clipboard.enable = true;
}
