{
  config,
  lib,
  pkgs,
  userConfig,
  runtime,
  ...
}:

let
  repoPath = ".config/angst";
  hostAngstPath = "/host${userConfig.homeDirectory}/${repoPath}";
in
{
  config = {
    assertions = [
      {
        assertion = config.services.openssh.enable or false;
        message = ''
          angst: VM is running without SSH. Headless VM access requires an SSH server.

          Ensure the VM profile modules are loaded. Add to your NixOS modules:
            domains/remote/ssh/system.nix
            ../lib/virtualization/vm-profile.nix

          And enable SSH:
            domains.remote.ssh.enable = true;
            domains.remote.ssh.server.enable = true;
        '';
      }
    ];

    documentation.nixos.enable = lib.mkForce false;

    # Don't persist SSH host keys on the VM — vm-ephemeral-ssh handles it.
    environment.persistence."/persist".directories = lib.mkForce [
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
    ];

    boot = {
      initrd.kernelModules = lib.mkForce [ ];
      kernelModules = lib.mkForce [ "virtio_gpu" ];
      kernelParams = lib.mkForce [ ];
    };

    services = {
      xserver = {
        enable = lib.mkForce true;
        videoDrivers = lib.mkForce [ "modesetting" ];
      };
      fstrim.enable = lib.mkForce false;
      spice-vdagentd.enable = true;
    };

    hardware = {
      cpu.amd.updateMicrocode = lib.mkForce false;
      graphics = {
        enable = lib.mkForce true;
        enable32Bit = lib.mkForce false;
        extraPackages = lib.mkForce [ ];
      };
    };

    domains.remote.ssh.enable = lib.mkForce true;
    domains.remote.ssh.server.enable = lib.mkForce true;

    environment = {
      systemPackages = with pkgs; [
        spice-vdagent
        pkg-config
        openssl.dev
        runtime.angstCli
      ];
      sessionVariables = {
        ANGST_REPO = hostAngstPath;
        PKG_CONFIG_PATH = "/run/current-system/sw/lib/pkgconfig";
      };
    };

    users.users.${userConfig.username}.openssh.authorizedKeys.keys =
      userConfig.ssh.authorizedKeys or [ ];

    systemd = {
      user.services.spice-vdagent = {
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

      services = {
        home-manager-upgrade = {
          description = "Activate latest Home Manager generation not baked into the system closure";
          after = [ "home-manager-${userConfig.username}.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = userConfig.username;
            ExecStart = (runtime.vm.homeManagerUpgrade { inherit (userConfig) username; }).bin;
          };
        };

        vm-ephemeral-ssh = {
          description = "VM: mount tmpfs on /etc/ssh for ephemeral host keys";
          wantedBy = [ "sshd-keygen.service" ];
          before = [
            "sshd-keygen.service"
            "sshd.service"
          ];
          after = [ "local-fs.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = runtime.vm.ephemeralSsh.bin;
          };
        };

        vm-authorized-keys = {
          description = "Install runtime SSH authorized_keys for VM access";
          wantedBy = [ "multi-user.target" ];
          before = [ "sshd.service" ];
          requires = [ "tmp-shared.mount" ];
          after = [ "tmp-shared.mount" ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart =
              (runtime.vm.authorizedKeys {
                inherit (userConfig) username homeDirectory;
              }).bin;
          };
        };

        vm-age-key = {
          description = "Install host age key for sops decryption";
          wantedBy = [ "multi-user.target" ];
          before = [ "home-manager-${userConfig.username}.service" ];
          requires = [ "tmp-shared.mount" ];
          after = [ "tmp-shared.mount" ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart =
              (runtime.vm.ageKey {
                inherit (userConfig) username homeDirectory;
              }).bin;
          };
        };
      };
    };

    home-manager.extraSpecialArgs.monitors = {
      primary = {
        name = "Virtual-1";
        resolution = "1920x1080";
        refreshRate = 60;
        position = "0x0";
      };
    };
  };
}
