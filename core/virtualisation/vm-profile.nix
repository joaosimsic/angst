{ config, lib, pkgs, userConfig, ... }:

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
    documentation.nixos.enable = lib.mkForce false;

    boot.initrd.kernelModules = lib.mkForce [ ];
    boot.kernelModules = lib.mkForce [ "virtio_gpu" ];
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

    services.spice-vdagentd.enable = true;

    environment.systemPackages = with pkgs; [
      spice-vdagent
      pkg-config
      openssl.dev
    ];

    environment.sessionVariables = {
      PKG_CONFIG_PATH = "/run/current-system/sw/lib/pkgconfig";
    };

    users.users.${userConfig.username}.openssh.authorizedKeys.keys =
      userConfig.ssh.authorizedKeys or [ ];

    systemd.user.services.spice-vdagent = {
      description = "SPICE vdagent session agent";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];

      unitConfig = {
        ConditionPathExists = "/run/spice-vdagentd/spice-vdagent-sock";
      };

      serviceConfig = {
        ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent -x";
        Restart = "on-failure";
      };
    };

    systemd.services.vm-authorized-keys = {
      description = "Install runtime SSH authorized_keys for VM access";
      wantedBy = [ "multi-user.target" ];
      before = [ "sshd.service" ];
      requires = [ "tmp-shared.mount" ];
      after = [ "tmp-shared.mount" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        key_file=/tmp/shared/authorized_keys

        if [ ! -s "$key_file" ]; then
          echo "No runtime VM SSH keys found at $key_file; keeping declarative authorized_keys fallback."
          exit 0
        fi

        install -d -m 700 -o ${userConfig.username} -g users ${userConfig.homeDirectory}/.ssh
        install -m 600 -o ${userConfig.username} -g users "$key_file" ${userConfig.homeDirectory}/.ssh/authorized_keys
      '';
    };

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
      fsType = "9p";
      neededForBoot = true;
      options = p9Options ++ [ "noatime" ];
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
