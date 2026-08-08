{
  config,
  lib,
  pkgs,
  userConfig,
  repoPath,
  ...
}:

let
  hostAngstPath = "/host${userConfig.homeDirectory}/${repoPath}";

  angstCli = pkgs.writeShellApplication {
    name = "angst";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      git
      nix
      watchexec
      jq
    ];
    text = builtins.readFile ../../scripts/angst.sh;
  };
in
{
  config = {
    assertions = [
      {
        assertion = config.services.openssh.enable or false;
        message = ''
          angst: VM is running without SSH. Headless VM access requires an SSH server.

          Ensure the VM profile modules are loaded. Add to your NixOS modules:
            ../capabilities/ssh.nix
            ../lib/virtualization/vm-profile.nix

          And enable SSH:
            capabilities.ssh.enable = true;
            capabilities.ssh.server.enable = true;
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

    capabilities.ssh.enable = lib.mkForce true;
    capabilities.ssh.server.enable = lib.mkForce true;

    environment = {
      systemPackages = with pkgs; [
        spice-vdagent
        pkg-config
        openssl.dev
        angstCli
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
          };
          script = ''
            active=""
            if [ -L "/etc/profiles/per-user/${userConfig.username}" ]; then
              active="$(readlink -f "/etc/profiles/per-user/${userConfig.username}")"
            fi

            latest=""
            for gen in /nix/store/*-home-manager-generation/activate; do
              [ -f "$gen" ] || continue
              dir="$(dirname "$gen")"
              hp="$(readlink "$dir/home-path" 2>/dev/null || true)"
              [ -n "$hp" ] || continue
              [ "$hp" = "$active" ] && continue
              latest="$dir"
            done

            if [ -n "$latest" ]; then
              exec "$latest/activate" --driver-version 1
            fi
          '';
        };

        vm-ephemeral-ssh = {
          description = "VM: mount tmpfs on /etc/ssh for ephemeral host keys";
          wantedBy = [ "sshd-keygen.service" ];
          before = [ "sshd-keygen.service" "sshd.service" ];
          after = [ "local-fs.target" ];
          serviceConfig.Type = "oneshot";
          script = ''
            mount -t tmpfs tmpfs /etc/ssh -o mode=0755
            for f in /run/current-system/etc/ssh/sshd_config /etc/static/ssh/sshd_config; do
              if [ -f "$f" ]; then
                cp "$f" /etc/ssh/sshd_config
                break
              fi
            done
          '';
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
