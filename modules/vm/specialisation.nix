{ lib, ... }:

{
  specialisation.vm.configuration = {
    angst.isQemuVm = lib.mkForce true;
  };
}
