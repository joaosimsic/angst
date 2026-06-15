{ lib, userConfig, ... }:

let
  virtiofsSocket = "${userConfig.homeDirectory}/.cache/angst/vhostqemu.sock";
in
{
  virtualisation.vmVariant = {
    angst.isQemuVm = lib.mkForce true;

    virtualisation.memorySize = 4096;
    virtualisation.cores = 4;
    virtualisation.diskSize = 16384;

    virtualisation.qemu.options = [
      "-device virtio-vga,xres=1920,yres=1080"
      "-display gtk,zoom-to-fit=on,grab-on-hover=on"
      "-chardev socket,id=angst-fs,path=${virtiofsSocket}"
      "-device vhost-user-fs-pci,queue-size=1024,chardev=angst-fs,tag=angst"
    ];
  };
}
