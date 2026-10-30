{ config, lib, ... }:

{
  options.angst.isQemuVm = lib.mkOption {
    type = lib.types.bool;
    default = false;
    internal = true;
    description = "Whether this config is a QEMU VM (boots without an on-disk bootloader).";
  };

  config = {
    boot.loader = {
      systemd-boot.enable = lib.mkForce (!config.angst.isQemuVm);
      efi.canTouchEfiVariables = lib.mkForce (!config.angst.isQemuVm);
      grub.enable = lib.mkIf config.angst.isQemuVm (lib.mkForce false);
    };
  };
}
