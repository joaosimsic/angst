{ config, lib, pkgs, userConfig, ... }:

{
  virtualisation.vmVariant = {
    virtualisation.memorySize = 4096;
    virtualisation.cores = 4;
    virtualisation.diskSize = 16384; 

    services.xserver.videoDrivers = lib.mkForce [ ];

    home-manager.extraSpecialArgs.monitors = {
      primary = {
        name = "Virtual-1";
        resolution = "1920x1080";
        refreshRate = 60;
        position = "0x0";
      };
    };

    services.spice-vdagentd.enable = true;
    capabilities.ssh.server.enable = true;
    capabilities.ssh.server.passwordAuthentication = true;

    users.users.joao.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOsmeoPJnZEE7AnCpSik4QsgjLr3cRy8W3Nmi0Ee5OF jpsimsic@hotmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEeJVdPiDa6ato/McVlwbjwifFmCoqF0/sPVCLSo82kQ joao.simsic@4x4brasil.com.br"
    ];

    virtualisation.qemu.options = [
      "-device virtio-vga,xres=1920,yres=1080"
      "-display gtk,zoom-to-fit=on,grab-on-hover=on"
      "-chardev qemu-vdagent,id=ch1,name=vdagent,clipboard=on"
      "-device virtio-serial-pci"
      "-device virtserialport,chardev=ch1,id=ch1,name=com.redhat.spice.0"
    ];
  };
}
