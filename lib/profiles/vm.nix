{ mkDomainEnable }:
{
  hm = [ ];
  nixos = [
    # VM detection — defines options.angst.isQemuVm
    ../../lib/virtualization/detect.nix
    # Bootloader: systemd-boot on bare metal, grub disabled in VM
    ../../lib/virtualization/runtime.nix
    # VM variant config (4 vCPUs, 4 GiB, virtio, SPICE)
    ../../lib/virtualization/vm-variant.nix
    # Full VM runtime profile (9p mounts, SSH keys, SPICE, etc.)
    ../../lib/virtualization/vm-profile.nix
    # Host mount symlink for live editing
    ../../lib/virtualization/host-mount.nix
    # SSH capability (vm-profile forces it on)
    ../../capabilities/ssh.nix
    ({ ... }: {
      capabilities.ssh.enable = true;
    })
  ];
}
