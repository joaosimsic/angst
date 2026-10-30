{
  lib,
  pkgs,
  userConfig,
  ...
}:

let
  repoPath = ".config/angst";
in
{
  virtualisation.vmVariant = {
    angst.isQemuVm = lib.mkForce true;

    boot = {
      initrd.kernelModules = lib.mkForce [ ];
      kernelModules = lib.mkForce [ "virtio_gpu" ];
      kernelParams = lib.mkForce [ ];
    };

    documentation.nixos.enable = lib.mkForce false;

    domains.display.lightdm.enable = lib.mkForce false;

    environment.systemPackages = [ pkgs.i3 ];

    hardware = {
      cpu.amd.updateMicrocode = lib.mkForce false;
      graphics = {
        enable = lib.mkForce true;
        enable32Bit = lib.mkForce false;
        extraPackages = lib.mkForce [ ];
      };
    };

    services = {
      displayManager.autoLogin = {
        enable = lib.mkForce true;
        user = lib.mkForce userConfig.username;
      };

      fstrim.enable = lib.mkForce false;

      spice-vdagentd.enable = true;

      xserver = {
        enable = lib.mkForce true;
        videoDrivers = lib.mkForce [ "modesetting" ];
        windowManager.i3.enable = lib.mkForce false;
      };
    };

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
      memorySize = 12288;
      cores = 4;
      diskSize = 32768;

      qemu.package = pkgs.qemu_kvm.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./qemu-super-grab.patch ];
      });

      qemu.options = [
        "-vga none"
        "-chardev qemu-vdagent,id=vdagent,name=vdagent,clipboard=on"
        "-device virtio-serial-pci"
        "-device virtserialport,chardev=vdagent,name=com.redhat.spice.0"
      ];

      sharedDirectories.angst = {
        source = "\${ANGST_REPO:-$PWD}";
        target = "/host${userConfig.homeDirectory}/${repoPath}";
        writable = true;
      };
    };
  };
}
