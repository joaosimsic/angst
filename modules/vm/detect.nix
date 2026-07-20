{
  lib,
  flakeSelf ? null,
  userConfig ? null,
  repoPath,
  ...
}:

let
  isQemuVm = import ./is-qemu-vm.nix { inherit lib flakeSelf userConfig repoPath; };
in
{
  options.angst.isQemuVm = lib.mkOption {
    internal = true;
    type = lib.types.bool;
    default = false;
    description = "Whether the system is a QEMU dev VM.";
  };

  config.angst.isQemuVm = lib.mkDefault isQemuVm;
}
