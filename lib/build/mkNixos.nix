{
  inputs,
  self,
  host,
  hmModules,
  nixosModules,
  runtime,
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

  appNixosModules = map host.scan.domains.mkNixosSystemModule host.scan.domains.systemEntries;
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

  secrets = import ../../modules/secrets.nix {
    inherit
      inputs
      self
      host
      lib
      ;
  };
in
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = {
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
    inherit runtime;
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
  ++ [
    inputs.sops-nix.nixosModules.sops
    secrets.systemCore
  ]
  ++ [
    ../../modules/vm/detect.nix
    ../../modules/vm/runtime.nix
    ../../modules/vm/vm-variant.nix
    ../../modules/vm/host-mount.nix
    (
      { config, lib, runtime, ... }:
      {
        users.users.${host.username}.hashedPassword = lib.mkDefault host.password;
        users.users.root.hashedPassword = lib.mkDefault host.password;

        systemd.services.angst-bootstrap-secrets = lib.mkIf secrets.canDecrypt {
          description = "angst: set login password hash and enforce SSH key passphrase from secrets";
          wantedBy = [ "multi-user.target" ];
          before = [
            "getty@.service"
            "serial-getty@.service"
            "display-manager.service"
          ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = (runtime.bootstrapSecrets {
              inherit (host) username hostname;
              sopsPath = config.sops.secrets.masterPassword.path;
            }).bin;
          };
        };
      }
    )
  ]
  ++ (if host.persist.enable then [ inputs.impermanence.nixosModules.impermanence ] else [ ])
  ++ (
    if host.persist.enable then
      [
        (import ../../modules/nixos/persist.nix {
          inherit lib;
          inherit (host) persist username;
          persistDirs = secrets.persistDirs ++ lib.optionals (host.projects != [ ]) [ "projects" ];
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
            projects
            ;
          hostName = host.hostname;
          inherit (host.scan) themes;
          themesLib = host.scan.themes;
          userConfig = userCfg;
          theme = effectiveTheme;
          flakeSelf = self;
          inherit runtime;
        };

        users.${host.username} = {
          imports = [
            ../../modules/home
            themeModule
          ]
          ++ appHomeModules
          ++ hmModules
          ++ host.toolchainModules
          ++ secrets.homeModules;
        };
      };
    }
    ({ config, lib, ... }: {
      systemd.services."home-manager-${host.username}".before = [
        "sshd.service"
      ]
      ++ lib.optionals (!config.angst.isQemuVm) [
        "getty@.service"
        "serial-getty@.service"
      ];
    })
  ];
}
