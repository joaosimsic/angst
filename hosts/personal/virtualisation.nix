{ config, lib, pkgs, ... }:

{
  virtualisation.vmVariant = {
    virtualisation.memorySize = 4096;
    virtualisation.cores = 4;

    home-manager.extraSpecialArgs.monitors = { };

    services.spice-vdagentd.enable = true;
    
    virtualisation.qemu.options = [
      "-vga virtio"
      "-display gtk,zoom-to-fit=on"
      "-chardev qemu-vdagent,id=ch1,name=vdagent,clipboard=on"
      "-device virtio-serial-pci"
      "-device virtserialport,chardev=ch1,id=ch1,name=com.redhat.spice.0"
    ];
  };
}
