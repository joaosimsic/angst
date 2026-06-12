{ config, lib, pkgs, ... }:

{
  virtualisation.vmVariant = {
    virtualisation.memorySize = 4096;
    virtualisation.cores = 4;

    home-manager.extraSpecialArgs.monitors = {
      primary = {
        name = "Virtual-1";
        resolution = "1920x1080";
        refreshRate = 60;
        position = "0x0";
      };
    };

    services.spice-vdagentd.enable = true;

    virtualisation.qemu.options = [
      "-device virtio-vga,xres=1920,yres=1080"
      "-display gtk,zoom-to-fit=on"
      "-chardev qemu-vdagent,id=ch1,name=vdagent,clipboard=on"
      "-device virtio-serial-pci"
      "-device virtserialport,chardev=ch1,id=ch1,name=com.redhat.spice.0"
    ];
  };
}
