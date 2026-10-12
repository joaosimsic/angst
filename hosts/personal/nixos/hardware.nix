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
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=4G"
        "mode=755"
      ];
    };
    "/home" = {
      device = "/dev/disk/by-label/data";
      fsType = "ext4";
      neededForBoot = true;
    };
    "/home/joao" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=8G"
        "mode=0700"
        "uid=1000"
        "gid=100"
      ];
      neededForBoot = true;
    };
    "/state" = {
      device = "/dev/disk/by-label/state";
      fsType = "ext4";
      neededForBoot = true;
    };
    "/nix" = {
      device = "/home/nix";
      fsType = "none";
      options = [ "bind" ];
      neededForBoot = true;
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/boot";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
  ];

  systemd.tmpfiles.rules = [
    "d /home/joao/.local/share 0755 joao users -"
    "d /home/steam 0755 joao users -"
    "d /home/prism 0755 joao users -"
    "L+ /home/joao/.local/share/Steam - - - - /home/steam"
    "L+ /home/joao/.local/share/PrismLauncher - - - - /home/prism"
  ];

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
