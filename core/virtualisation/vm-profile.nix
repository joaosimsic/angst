{ config, lib, userConfig, ... }:

let
  cfg = config.angst.isQemuVm;

  hostAngstPath = "/host${userConfig.homeDirectory}/proj/angst";

  p9Options = [
    "trans=virtio"
    "version=9p2000.L"
    "msize=16384"
    "x-systemd.requires=modprobe@9pnet_virtio.service"
  ];
in
{
  config = lib.mkIf cfg {
    boot.initrd.kernelModules = lib.mkForce [ "virtiofs" ];
    boot.kernelModules = lib.mkForce [ "virtiofs" "virtio_gpu" ];
    boot.kernelParams = lib.mkForce [ ];

    services.xserver = {
      enable = lib.mkForce true;
      videoDrivers = lib.mkForce [ "modesetting" ];
    };

    services.fstrim.enable = lib.mkForce false;

    hardware.cpu.amd.updateMicrocode = lib.mkForce false;

    hardware.graphics = {
      enable = lib.mkForce true;
      enable32Bit = lib.mkForce false;
      extraPackages = lib.mkForce [ ];
    };

    capabilities.ssh.server.enable = lib.mkForce true;

    users.users.${userConfig.username}.openssh.authorizedKeys.keys =
      userConfig.ssh.authorizedKeys or [ ];

    home-manager.extraSpecialArgs.monitors = {
      primary = {
        name = "Virtual-1";
        resolution = "1920x1080";
        refreshRate = 60;
        position = "0x0";
      };
    };

    fileSystems."/" = lib.mkForce {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

    fileSystems.${hostAngstPath} = {
      device = "angst";
      fsType = "virtiofs";
      neededForBoot = true;
      options = [ "noatime" ];
    };

    fileSystems."/nix/.ro-store" = {
      device = "nix-store";
      fsType = "9p";
      neededForBoot = true;
      options = p9Options ++ [ "cache=loose" ];
    };

    fileSystems."/nix/.rw-store" = {
      device = "tmpfs";
      fsType = "tmpfs";
      neededForBoot = true;
      options = [ "mode=0755" ];
    };

    fileSystems."/nix/store" = {
      overlay = {
        lowerdir = [ "/nix/.ro-store" ];
        upperdir = "/nix/.rw-store/upper";
        workdir = "/nix/.rw-store/work";
      };
    };

    fileSystems."/tmp/shared" = {
      device = "shared";
      fsType = "9p";
      neededForBoot = true;
      options = p9Options;
    };

    fileSystems."/tmp/xchg" = {
      device = "xchg";
      fsType = "9p";
      neededForBoot = true;
      options = p9Options;
    };
  };
}
