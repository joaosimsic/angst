{ lib, userConfig, ... }:

{
  virtualisation.vmVariant = {
    angst.isQemuVm = lib.mkForce true;

    virtualisation.memorySize = 4096;
    virtualisation.cores = 4;
    virtualisation.diskSize = 16384;

    virtualisation.qemu.options = [
      "-device virtio-vga,xres=1920,yres=1080"
      "-display gtk,zoom-to-fit=on,grab-on-hover=on"
    ];

    virtualisation.sharedDirectories.angst = {
      source = "${userConfig.homeDirectory}/proj/angst";
      target = "/host${userConfig.homeDirectory}/proj/angst";
      securityModel = "none";
    };
  };
}
