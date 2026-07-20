{ mkDomainEnable, mkCap }:
{
  hm = [ ];
  nixos = [
    ../modules/nixos/detect.nix
    ../modules/nixos/runtime.nix
    ../modules/nixos/vm-variant.nix
    ../modules/nixos/vm-profile.nix
    ../modules/nixos/host-mount.nix
    (mkCap "ssh")
  ];
}
