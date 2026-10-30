{
  type = "nixos";
  system = "x86_64-linux";
  hostname = "generic";
  username = "user";
  theme = "miasma";
  profiles = [ "generic" ];
  toolchains = [
    "nix"
    "bash"
    "json"
    "yaml"
  ];

  monitors = { };
  db = [ ];
  secrets = [ "opencode-go-key" ];
  persist = {
    enable = false;
  };
  sshAgent = {
    enable = false;
  };
  shell = "";

  nixos =
    { pkgs, ... }:
    {
      imports = [ ./storage.nix ];

      angst.genericHost = {
        enable = true;
        acknowledgeDiskChanges = true;
      };

      boot.initrd.availableKernelModules = [
        "btrfs"
        "crc32c"
        "nvme"
        "ahci"
        "sd_mod"
        "sr_mod"
        "usb_storage"
        "uas"
        "xhci_pci"
        "ehci_pci"
        "usbhid"
        "hid_generic"
        "virtio_pci"
        "virtio_blk"
        "virtio_scsi"
        "virtio_net"
        "ext4"
        "xfs"
        "f2fs"
        "vfat"
        "dm_mod"
        "dm_crypt"
        "md_mod"
      ];

      hardware = {
        enableRedistributableFirmware = true;
        cpu = {
          intel.updateMicrocode = true;
          amd.updateMicrocode = true;
        };
        graphics.enable = true;
      };
      zramSwap.enable = true;

      environment.systemPackages = with pkgs; [
        neovim
        git
        openssh
        pciutils
        usbutils
        lshw
        dmidecode
        inxi
        lm_sensors
        smartmontools
        nvme-cli
        ethtool
        iw
        btrfs-progs
        gptfdisk
        parted
        dosfstools
        e2fsprogs
        util-linux
        psmisc
        strace
        nixos-install-tools
      ];
    };
}
