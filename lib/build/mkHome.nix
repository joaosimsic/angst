{
  inputs,
  self,
  cfg,
  hmModules,
  vmTool,
  shellTool,
  angstTool,
  themeOverride ? null,
  shellOverride ? null,
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

  appHomeModules = map cfg.scan.domains.mkDomainModule cfg.scan.domains.homeEntries;

  themeModule = import ../../modules/home/themeModule.nix {
    inherit lib;
    themesLib = cfg.scan.themes;
    hostTheme = effectiveTheme;
  };

  secretsFile =
    if cfg.domain != null then
      self + "/hosts/${cfg.domain}/${cfg.hostname}/secrets.yaml"
    else
      self + "/hosts/${cfg.hostname}/secrets.yaml";
  hasSecrets = builtins.pathExists secretsFile;
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  extraSpecialArgs = {
    inherit (cfg)
      hostname
      monitors
      repoPath
      db
      sshAgent
      ssh
      ;
    shell = if shellOverride != null then shellOverride else cfg.shell;
    inherit (cfg.scan) themes;
    themesLib = cfg.scan.themes;
    hostName = cfg.hostname;
    userConfig = userCfg;
    theme = effectiveTheme;
    flakeSelf = self;
  };

  modules = [
    ../../modules/home
    themeModule
  ]
  ++ appHomeModules
  ++ hmModules
  ++ cfg.toolchainModules
  ++ [ inputs.sops-nix.homeManagerModules.sops ]
  ++ (
    if hasSecrets then
      [ { sops.defaultSopsFile = secretsFile; } ]
    else
      [ ]
  )
  ++ [
    (_: {
      home.packages = [
        vmTool
        shellTool
        angstTool
      ];
    })
  ]
  ++ [
    ({ config, pkgs, lib, ... }: lib.mkIf hasSecrets {
      sops.secrets = {
        masterPassword = { };
      };

      home.activation.angstSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        ''
          set -euo pipefail

          MASTER_PASSWORD=$(cat ''
        + lib.escapeShellArg config.sops.secrets.masterPassword.path
        + ''
          )

          KEY_FILE="$HOME/.ssh/id_ed25519"
          SSH_DIR="$HOME/.ssh"

          set +x
          if [ ! -f "$KEY_FILE" ]; then
            mkdir -p "$SSH_DIR"
            ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$KEY_FILE" -N "$MASTER_PASSWORD" -C "${cfg.username}@${cfg.hostname}"
          else
            if ! ${pkgs.openssh}/bin/ssh-keygen -y -P "$MASTER_PASSWORD" -f "$KEY_FILE" > /dev/null 2>&1; then
              ${pkgs.openssh}/bin/ssh-keygen -p -N "$MASTER_PASSWORD" -f "$KEY_FILE" 2>/dev/null || \
                ${pkgs.openssh}/bin/ssh-keygen -p -P "" -N "$MASTER_PASSWORD" -f "$KEY_FILE" 2>/dev/null
            fi
          fi
          unset MASTER_PASSWORD
          set -x
        ''
      );
    })
  ]
  ++ (if cfg.extraHome != { } then [ cfg.extraHome ] else [ ])
  ++ (if cfg.env != { } then [ { home.sessionVariables = cfg.env; } ] else [ ]);
}
