{ config, lib, ... }:

{
  config = {
    boot.loader = {
      systemd-boot.enable = lib.mkIf (!config.angst.isQemuVm) true;
      efi.canTouchEfiVariables = lib.mkIf (!config.angst.isQemuVm) true;
      grub.enable = lib.mkIf config.angst.isQemuVm (lib.mkForce false);
    };
  };
}
