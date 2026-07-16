{ pkgs, hostname, ... }:

{
  imports = [
    ./hardware.nix
    ../../common/capabilities.nix
    ../../lib/virtualisation
  ];

  networking.hostName = hostname;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "amd_pstate=active" ];
    initrd.kernelModules = [ "amdgpu" ];
  };

  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [ rocmPackages.clr.icd ];
    };
    cpu.amd.updateMicrocode = true;
  };

  capabilities = {
    audio.enable = true;
    graphical.enable = true;
    ssh.enable = true;
    clipboard.enable = true;
  };
}
