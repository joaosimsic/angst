{
  lib,
  flakeSelf ? null,
  userConfig ? null,
  ...
}:

let
  isQemuVm = import ./is-qemu-vm.nix { inherit lib flakeSelf userConfig; };
in
{
  options.angst.isQemuVm = lib.mkOption {
    internal = true;
    type = lib.types.bool;
    default = isQemuVm;
    description = "Whether the system is a QEMU dev VM.";
  };
}
