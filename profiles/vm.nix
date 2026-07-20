{ mkDomainEnable, mkCap }:
{
  hm = [ ];
  nixos = [
    ../lib/virtualization/detect.nix
    ../lib/virtualization/runtime.nix
    ../lib/virtualization/vm-variant.nix
    ../lib/virtualization/vm-profile.nix
    ../lib/virtualization/host-mount.nix
    (mkCap "ssh")
  ];
}
