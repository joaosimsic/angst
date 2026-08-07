{
  inputs,
  self,
  cfg,
  hmModules,
  nixosModules,
  themeOverride ? null,
}:

let
  pkgs = import inputs.nixpkgs {
    inherit (cfg) system;
    config = import ../nixpkgs-config.nix;
  };
  inherit (pkgs) lib;

  effectiveTheme = if themeOverride != null then themeOverride else cfg.theme;
  userCfg = {
    inherit (cfg) username;
    homeDirectory = "/home/${cfg.username}";
  };

  appNixosModules = map cfg.scan.domains.mkNixosDomainModule cfg.scan.domains.nixosEntries;
  appHomeModules = map cfg.scan.domains.mkDomainModule cfg.scan.domains.homeEntries;

  themeModule = import ../../modules/home/themeModule.nix {
    inherit lib;
    themesLib = cfg.scan.themes;
    hostTheme = effectiveTheme;
  };

  hardwarePath =
    let
      p =
        if cfg.domain != null then
          self + "/hosts/${cfg.domain}/${cfg.hostname}/hardware.nix"
        else
          self + "/hosts/${cfg.hostname}/hardware.nix";
    in
    if builtins.pathExists p then p else null;

  secretsFile =
    if cfg.domain != null then
      self + "/hosts/${cfg.domain}/${cfg.hostname}/secrets.yaml"
    else
      self + "/hosts/${cfg.hostname}/secrets.yaml";
  hasSecrets = builtins.pathExists secretsFile;
in
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = {
    inherit (cfg)
      hostname
      monitors
      repoPath
      db
      sshAgent
      shell
      ;
    hostName = cfg.hostname;
    inherit (cfg.scan) themes;
    themesLib = cfg.scan.themes;
    userConfig = userCfg;
    theme = effectiveTheme;
    flakeSelf = self;
  };

  modules = [
    { nixpkgs.hostPlatform = cfg.system; }
  ]
  ++ nixosModules
  ++ appNixosModules
  ++ [ ../../modules/nixos ]
  ++ (if hardwarePath != null then [ (import hardwarePath) ] else [ ])
  ++ (if cfg.extraNixos != { } then [ cfg.extraNixos ] else [ ])
  ++ (if cfg.env != { } then [ { environment.sessionVariables = cfg.env; } ] else [ ])
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
      users.users.${cfg.username}.hashedPassword = lib.mkDefault cfg.password;
      users.users.root.hashedPassword = lib.mkDefault cfg.password;

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
          ${pkgs.shadow}/bin/usermod -p "$HASH" ${cfg.username}
          ${pkgs.shadow}/bin/usermod -p "$HASH" root

          KEY_FILE="/home/${cfg.username}/.ssh/id_ed25519"
          SSH_DIR="$(dirname "$KEY_FILE")"

          if [ ! -f "$KEY_FILE" ]; then
            mkdir -p "$SSH_DIR"
            ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$KEY_FILE" -N "$MASTER_PASSWORD" -C "${cfg.username}@${cfg.hostname}"
            chown -R ${cfg.username}: "$SSH_DIR"
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
  ++ (if cfg.persist.enable then [ inputs.impermanence.nixosModules.impermanence ] else [ ])
  ++ (
    if cfg.persist.enable then
      [
        (_: {
          environment.persistence."${cfg.persist.root}" = {
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
            users.${cfg.username} = {
              directories = map (d: "/home/${cfg.username}/${d}") cfg.persist.homeDirs;
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
          inherit (cfg)
            hostname
            monitors
            repoPath
            db
            sshAgent
            ssh
            shell
            ;
          hostName = cfg.hostname;
          inherit (cfg.scan) themes;
          themesLib = cfg.scan.themes;
          userConfig = userCfg;
          theme = effectiveTheme;
          flakeSelf = self;
        };

        users.${cfg.username} = {
          imports = [
            ../../modules/home
            themeModule
          ]
          ++ appHomeModules
          ++ hmModules
          ++ cfg.toolchainModules;
        };
      };
    }
    ({ config, lib, ... }: {
      systemd.services."home-manager-${cfg.username}".before = lib.mkIf (!config.angst.isQemuVm) [
        "getty@.service"
        "serial-getty@.service"
      ];
    })
  ];
}
