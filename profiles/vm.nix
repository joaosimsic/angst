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
  ];
}
