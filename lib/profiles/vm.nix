{ mkDomainEnable }:
{
  hm = [ ];
  nixos = [
    # VM detection — defines options.angst.isQemuVm
    ../../lib/virtualisation/detect.nix
    # Bootloader: systemd-boot on bare metal, grub disabled in VM
    ../../lib/virtualisation/runtime.nix
    # VM boot specialisation entry
    ../../lib/virtualisation/specialisation.nix
    # VM variant config (4 vCPUs, 4 GiB, virtio, SPICE)
    ../../lib/virtualisation/vm-variant.nix
    # Full VM runtime profile (9p mounts, SSH keys, SPICE, etc.)
    ../../lib/virtualisation/vm-profile.nix
    # Host mount symlink for live editing
    ../../lib/virtualisation/host-mount.nix
    # SSH capability (vm-profile forces it on)
    ../../capabilities/ssh.nix
    ({ ... }: {
      capabilities.ssh.enable = true;
    })
  ];
}
