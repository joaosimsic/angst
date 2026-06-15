{ lib, flakeSelf ? null, ... }:

let
  isQemuVm = import ../../lib/system/isQemuVm.nix { inherit lib flakeSelf; };
in
{
  options.angst.isQemuVm = lib.mkOption {
    internal = true;
    type = lib.types.bool;
    default = isQemuVm;
    readOnly = true;
    description = "Whether the system is a QEMU dev VM (detected via flake .vm marker).";
  };

  config = {
    boot.loader.systemd-boot.enable = lib.mkIf (!isQemuVm) true;
    boot.loader.efi.canTouchEfiVariables = lib.mkIf (!isQemuVm) true;
    boot.loader.grub.enable = lib.mkIf isQemuVm (lib.mkForce false);
  };
}
