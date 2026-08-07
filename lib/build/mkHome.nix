{
  inputs,
  self,
  host,
  hmModules,
  vmTool,
  shellTool,
  angstTool,
  themeOverride ? null,
  shellOverride ? null,
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

  appHomeModules = map host.scan.domains.mkDomainModule host.scan.domains.homeEntries;

  themeModule = import ../../modules/home/themeModule.nix {
    inherit lib;
    themesLib = host.scan.themes;
    hostTheme = effectiveTheme;
  };

  secretsFile =
    if host.domain != null then
      self + "/hosts/${host.domain}/${host.hostname}/secrets.yaml"
    else
      self + "/hosts/${host.hostname}/secrets.yaml";
  hasSecrets = builtins.pathExists secretsFile;
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  extraSpecialArgs = {
    inherit (host)
      hostname
      monitors
      repoPath
      db
      sshAgent
      ssh
      ;
    shell = if shellOverride != null then shellOverride else host.shell;
    inherit (host.scan) themes;
    themesLib = host.scan.themes;
    hostName = host.hostname;
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
  ++ host.toolchainModules
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
            ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$KEY_FILE" -N "$MASTER_PASSWORD" -C "${host.username}@${host.hostname}"
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
  ++ (if host.extraHome != { } then [ host.extraHome ] else [ ])
  ++ (if host.env != { } then [ { home.sessionVariables = host.env; } ] else [ ]);
}
