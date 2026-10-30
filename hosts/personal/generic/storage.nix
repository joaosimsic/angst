# GENERIC-PROVISION-PLACEHOLDER
# Replaced by `nix run .#generic-provision` after the Calamares btrfs install.
{ config, ... }:
{
  assertions = [
    {
      assertion = config.networking.hostName == "generic";
      message = "hosts/personal/generic/storage.nix may only be imported by the generic host";
    }
  ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "compress=zstd"
        "noatime"
        "subvol=@root"
      ];
    };

    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "compress=zstd"
        "noatime"
        "subvol=@home"
      ];
      neededForBoot = true;
    };

    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "compress=zstd"
        "noatime"
        "subvol=@nix"
      ];
      neededForBoot = true;
    };

    "/boot" = {
      device = "/dev/disk/by-partlabel/boot";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  swapDevices = [ ];
}
