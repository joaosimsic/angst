{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usbhid"
      ];
      kernelModules = [ ];
    };
    kernelModules = [
      "kvm-amd"
      "nct6775"
    ];
    extraModulePackages = [ ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/d61dd677-665b-4600-afac-7cdc169e043b";
      fsType = "ext4";
    };
    "/home" = {
      device = "/dev/disk/by-uuid/9577720e-6962-434c-a0a2-39300244b8ea";
      fsType = "ext4";
      neededForBoot = true;
    };
    "/nix" = {
      device = "/home/nix";
      fsType = "none";
      options = [ "bind" ];
    };
    "/var/lib/ollama" = {
      device = "/home/ollama_data";
      fsType = "none";
      options = [ "bind" ];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/2CE5-C81F";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/4ea63f7b-5e3b-4ab7-a9bf-75742248aa2b"; }
  ];

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
