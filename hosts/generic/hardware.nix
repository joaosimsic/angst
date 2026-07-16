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
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];
  };

  hardware.enableRedistributableFirmware = true;

  fileSystems = {
    "/" = {
      device = lib.mkDefault "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    "/boot" = lib.mkIf (!config.angst.isQemuVm) {
      device = lib.mkDefault "/dev/disk/by-label/BOOT";
      fsType = "vfat";
    };
  };
}
