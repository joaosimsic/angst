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
  config.angst.isQemuVm = lib.mkDefault isQemuVm;
}
