{ config, lib, ... }:

{
  config = {
    boot.loader.systemd-boot.enable = lib.mkIf (!config.angst.isQemuVm) true;
    boot.loader.efi.canTouchEfiVariables = lib.mkIf (!config.angst.isQemuVm) true;
    boot.loader.grub.enable = lib.mkIf config.angst.isQemuVm (lib.mkForce false);
  };
}
