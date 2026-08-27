{
  enable = [
    "remote.ssh"
    "display.ly"
  ];
  modules = [
    ../modules/vm/runtime.nix
    ../modules/vm/vm-variant.nix
    ../modules/vm/vm-profile.nix
    ../modules/vm/host-mount.nix
    ({ lib, ... }: {
      config.angst.isQemuVm = lib.mkForce true;
      config.domains.display.lightdm.enable = lib.mkForce false;
    })
  ];
}
