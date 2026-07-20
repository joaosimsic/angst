{ mkDomainEnable, mkCap }:
{
  hm = [ ];
  nixos = [
    ../modules/vm/detect.nix
    ../modules/vm/runtime.nix
    ../modules/vm/vm-variant.nix
    ../modules/vm/vm-profile.nix
    ../modules/vm/host-mount.nix
    (mkCap "ssh")
  ];
}
