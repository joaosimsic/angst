{
  lib,
  userConfig,
  repoPath,
  ...
}:

{
  virtualisation.vmVariant = {
    angst.isQemuVm = lib.mkForce true;

    virtualisation.fileSystems = {
      "/" = lib.mkForce {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [
          "defaults"
          "size=2G"
          "mode=755"
        ];
      };
      "/persist" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
        neededForBoot = true;
      };
    };

    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 16384;

      qemu.options = [
        "-device virtio-vga,xres=1920,yres=1080"
        "-display gtk,zoom-to-fit=on,grab-on-hover=on"
        "-chardev qemu-vdagent,id=vdagent,name=vdagent,clipboard=on"
        "-device virtio-serial-pci"
        "-device virtserialport,chardev=vdagent,name=com.redhat.spice.0"
      ];

      sharedDirectories.angst = {
        source = "\${ANGST_REPO:-$PWD}";
        target = "/host${userConfig.homeDirectory}/${repoPath}";
        securityModel = "none";
      };
    };
  };
}
