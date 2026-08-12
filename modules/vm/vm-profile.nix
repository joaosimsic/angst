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
      sops
      age
      openssl
      diffutils
    ];
    text = builtins.concatStringsSep "\n" (
      map builtins.readFile [
        ../../scripts/angst-lib.sh
        ../../scripts/angst-bootstrap-secrets.sh
        ../../scripts/angst-render.sh
        ../../scripts/angst-watch.sh
        ../../scripts/angst-projects.sh
        ../../scripts/angst.sh
      ]
    );
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
            active_hp=""
            service_exec="$(systemctl show home-manager-${userConfig.username} -p ExecStart 2>/dev/null || true)"
            active_gen="$(echo "$service_exec" | sed -n 's/.* \([^ ]*\)-home-manager-generation.*/\1-home-manager-generation/p')"
            if [ -n "$active_gen" ] && [ -L "$active_gen/home-path" ]; then
              active_hp="$(readlink -f "$active_gen/home-path" 2>/dev/null || true)"
            fi

            if [ -z "$active_hp" ]; then
              echo "Could not determine active home-manager-path; nothing to upgrade."
              exit 0
            fi

            latest=""
            shopt -s nullglob 2>/dev/null || true
            for gen in /nix/store/*-home-manager-generation/activate; do
              [ -f "$gen" ] || continue
              dir="''${gen%/activate}" || continue
              hp="$(readlink -f "$dir/home-path" 2>/dev/null || true)"
              [ -n "$hp" ] || continue
              [ "$hp" = "$active_hp" ] && continue
              latest="$dir"
            done

            if [ -n "$latest" ] && [ -x "$latest/activate" ]; then
              "$latest/activate" --driver-version 1 || true
            fi
          '';
        };

        vm-ephemeral-ssh = {
          description = "VM: mount tmpfs on /etc/ssh for ephemeral host keys";
          wantedBy = [ "sshd-keygen.service" ];
          before = [
            "sshd-keygen.service"
            "sshd.service"
          ];
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

        vm-age-key = {
          description = "Install host age key for sops decryption";
          wantedBy = [ "multi-user.target" ];
          before = [ "home-manager-${userConfig.username}.service" ];
          requires = [ "tmp-shared.mount" ];
          after = [ "tmp-shared.mount" ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };

          script = ''
            key_file=/tmp/shared/age-keys.txt

            if [ ! -s "$key_file" ]; then
              echo "No host age key found at $key_file; secrets will be unavailable."
              exit 0
            fi

            sops_dir="${userConfig.homeDirectory}/.config/sops/age"
            install -d -m 700 -o ${userConfig.username} -g users "$sops_dir"
            install -m 600 -o ${userConfig.username} -g users "$key_file" "$sops_dir/keys.txt"
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
