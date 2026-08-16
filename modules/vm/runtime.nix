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
      systemd-boot.enable = lib.mkIf (!config.angst.isQemuVm) true;
      efi.canTouchEfiVariables = lib.mkIf (!config.angst.isQemuVm) true;
      grub.enable = lib.mkIf config.angst.isQemuVm (lib.mkForce false);
    };
  };
}
