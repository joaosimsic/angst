{
  inputs,
  self,
  host,
  hmModules,
  nixosModules,
  themeOverride ? null,
}:

let
  pkgs = import inputs.nixpkgs {
    inherit (host) system;
    config = import ../nixpkgs-config.nix;
  };
  inherit (pkgs) lib;

  effectiveTheme = if themeOverride != null then themeOverride else host.theme;
  userCfg = {
    inherit (host) username;
    homeDirectory = "/home/${host.username}";
  };

  appNixosModules = map host.scan.domains.mkNixosDomainModule host.scan.domains.nixosEntries;
  appHomeModules = map host.scan.domains.mkDomainModule host.scan.domains.homeEntries;

  themeModule = import ../../modules/home/themeModule.nix {
    inherit lib;
    themesLib = host.scan.themes;
    hostTheme = effectiveTheme;
  };

  hardwarePath =
    let
      p =
        if host.domain != null then
          self + "/hosts/${host.domain}/${host.hostname}/hardware.nix"
        else
          self + "/hosts/${host.hostname}/hardware.nix";
    in
    if builtins.pathExists p then p else null;

  secretsFile =
    if host.domain != null then
      self + "/hosts/${host.domain}/${host.hostname}/secrets.yaml"
    else
      self + "/hosts/${host.hostname}/secrets.yaml";
  hasSecrets = builtins.pathExists secretsFile;
in
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = {
    inherit (host)
      hostname
      monitors
      repoPath
      db
      sshAgent
      shell
      ;
    hostName = host.hostname;
    inherit (host.scan) themes;
    themesLib = host.scan.themes;
    userConfig = userCfg;
    theme = effectiveTheme;
    flakeSelf = self;
  };

  modules = [
    { nixpkgs.hostPlatform = host.system; }
  ]
  ++ nixosModules
  ++ appNixosModules
  ++ [ ../../modules/nixos ]
  ++ (if hardwarePath != null then [ (import hardwarePath) ] else [ ])
  ++ (if host.extraNixos != { } then [ host.extraNixos ] else [ ])
  ++ (if host.env != { } then [ { environment.sessionVariables = host.env; } ] else [ ])
  ++ [ inputs.sops-nix.nixosModules.sops ]
  ++ (
    if hasSecrets then
      [ { sops.defaultSopsFile = secretsFile; } ]
    else
      [ ]
  )
  ++ [
    ../../modules/vm/detect.nix
    ../../modules/vm/runtime.nix
    ../../modules/vm/vm-variant.nix
    ../../modules/vm/vm-profile.nix
    ../../modules/vm/host-mount.nix
    ../../capabilities/ssh.nix
    ({ config, pkgs, ... }: {
      users.users.${host.username}.hashedPassword = lib.mkDefault host.password;
      users.users.root.hashedPassword = lib.mkDefault host.password;

      sops.secrets = lib.mkIf hasSecrets {
        masterPassword = { };
      };

      systemd.services.angst-bootstrap-secrets = lib.mkIf (hasSecrets && !config.angst.isQemuVm) {
        description = "angst: set login password hash and enforce SSH key passphrase from secrets";
        wantedBy = [ "multi-user.target" ];
        after = [ "sops-nix.service" ];
        before = [ "getty@.service" "serial-getty@.service" "display-manager.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          set -euo pipefail

          MASTER_PASSWORD=$(cat ''${config.sops.secrets.masterPassword.path})

          set +x
          HASH=$(echo "$MASTER_PASSWORD" | ${pkgs.mkpasswd}/bin/mkpasswd -m sha-512 -s)
          ${pkgs.shadow}/bin/usermod -p "$HASH" ${host.username}
          ${pkgs.shadow}/bin/usermod -p "$HASH" root

          KEY_FILE="/home/${host.username}/.ssh/id_ed25519"
          SSH_DIR="$(dirname "$KEY_FILE")"

          if [ ! -f "$KEY_FILE" ]; then
            mkdir -p "$SSH_DIR"
            ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$KEY_FILE" -N "$MASTER_PASSWORD" -C "${host.username}@${host.hostname}"
            chown -R ${host.username}: "$SSH_DIR"
          else
            if ! ${pkgs.openssh}/bin/ssh-keygen -y -P "$MASTER_PASSWORD" -f "$KEY_FILE" > /dev/null 2>&1; then
              ${pkgs.openssh}/bin/ssh-keygen -p -N "$MASTER_PASSWORD" -f "$KEY_FILE" 2>/dev/null || \
                ${pkgs.openssh}/bin/ssh-keygen -p -P "" -N "$MASTER_PASSWORD" -f "$KEY_FILE" 2>/dev/null
            fi
          fi

          unset MASTER_PASSWORD
          set -x
        '';
      };
    })
  ]
  ++ (if host.persist.enable then [ inputs.impermanence.nixosModules.impermanence ] else [ ])
  ++ (
    if host.persist.enable then
      [
        (_: {
          environment.persistence."${host.persist.root}" = {
            hideMounts = true;
            directories = [
              "/var/log"
              "/var/lib/bluetooth"
              "/var/lib/nixos"
              "/var/lib/systemd/coredump"
              "/etc/ssh"
            ];
            files = [
              "/etc/machine-id"
            ];
            users.${host.username} = {
              directories = map (d: "/home/${host.username}/${d}") host.persist.homeDirs;
            };
          };
        })
      ]
    else
      [ ]
  )
  ++ [
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "hm-backup";

        extraSpecialArgs = {
          inherit (host)
            hostname
            monitors
            repoPath
            db
            sshAgent
            ssh
            shell
            ;
          hostName = host.hostname;
          inherit (host.scan) themes;
          themesLib = host.scan.themes;
          userConfig = userCfg;
          theme = effectiveTheme;
          flakeSelf = self;
        };

        users.${host.username} = {
          imports = [
            ../../modules/home
            themeModule
          ]
          ++ appHomeModules
          ++ hmModules
          ++ host.toolchainModules;
        };
      };
    }
    ({ config, lib, ... }: {
      systemd.services."home-manager-${host.username}".before = lib.mkIf (!config.angst.isQemuVm) [
        "getty@.service"
        "serial-getty@.service"
      ];
    })
  ];
}
