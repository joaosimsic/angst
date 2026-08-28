{
  config,
  lib,
  pkgs,
  userConfig,
  runtime,
  flakeSelf,
  ssh,
  ...
}:

let
  repoPath = ".config/angst";
  hostAngstPath = "/host${userConfig.homeDirectory}/${repoPath}";

  sharedPubs =
    let
      pubFor =
        scope:
        let
          p = flakeSelf + "/secrets/ssh/${scope}.ed25519.pub";
        in
        lib.optional (builtins.pathExists p) (lib.trim (builtins.readFile p));
    in
    (pubFor "personal") ++ (pubFor "work");
in
{
  options.angst.vm.injectWorkAgeKey = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Inject the work age key into the VM (needed to decrypt work-scoped secrets such as ftp mounts). Every host must be able to use the work key.";
  };

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

    environment.persistence."/persist".directories = lib.mkForce [
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

    services.openssh.settings.AuthorizedKeysFile = "/etc/ssh/authorized_keys.d/%u";

    services.openssh.settings.PerSourcePenalties = lib.mkForce false;

    environment = {
      systemPackages = with pkgs; [
        spice-vdagent
        pkg-config
        openssl.dev
        runtime.angst-cli
        runtime.vm.nixos-switch
        runtime.vm.home-switch
      ];
      sessionVariables = {
        ANGST_REPO = hostAngstPath;
        PKG_CONFIG_PATH = "/run/current-system/sw/lib/pkgconfig";
      };
    };

    users.users.${userConfig.username}.openssh.authorizedKeys.keys =
      sharedPubs ++ (ssh.authorizedKeys or [ ]);

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
            ExecStart = (runtime.vm.home-manager-upgrade { inherit (userConfig) username; }).bin;
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
            ExecStart = runtime.vm.ephemeral-ssh.bin;
          };
        };

        vm-age-key = {
          description = "Install host age key for age decryption";
          wantedBy = [ "multi-user.target" ];
          before = [ "home-manager-${userConfig.username}.service" ];
          requires = [ "tmp-shared.mount" ];
          after = [ "tmp-shared.mount" ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart =
              (runtime.vm.age-key {
                inherit (userConfig) username homeDirectory;
                injectWorkKey = config.angst.vm.injectWorkAgeKey;
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
