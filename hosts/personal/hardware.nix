{ config, lib, pkgs, modulesPath, flakeSelf ? null, ... }:

let
  isQemuVm = import ../../lib/system/isQemuVm.nix { inherit lib flakeSelf; };
in

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod"
  ];

  boot.kernelModules = [ "kvm-amd" ];

  hardware.enableRedistributableFirmware = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/root";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkIf (!isQemuVm) {
    device = "/dev/vda1";
    fsType = "vfat";
  };
}

