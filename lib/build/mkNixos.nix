{
  inputs,
  self,
  host,
  hmModules,
  nixosModules,
  runtime,
  themeOverride ? null,
  store,
}:

let
  pkgs =
    host.pkgs or (import inputs.nixpkgs {
      inherit (host) system;
      config = import ../nixpkgs-config.nix;
    });
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
      self
      host
      lib
      ;
  };

  masterAgePath = self + "/secrets/master/${host.hostname}.age";
in
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = {
    inherit (host)
      hostname
      monitors
      db
      sshAgent
      ssh
      shell
      ;
    hostType = host.type;
    hostScopes = host.scopes;
    hostSecrets = host.secrets;
    hostName = host.hostname;
    inherit (host.scan) themes;
    themesLib = host.scan.themes;
    userConfig = userCfg;
    theme = effectiveTheme;
    flakeSelf = self;
    inherit inputs runtime store;
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
    ../../modules/vm/runtime.nix
    ../../modules/vm/vm-variant.nix
    ../../modules/vm/host-mount.nix
    (
      {
        lib,
        runtime,
        ...
      }:
      {
        users.users.${host.username}.hashedPassword = lib.mkDefault host.password;
        users.users.root.hashedPassword = lib.mkDefault host.password;

        systemd.services.angst-bootstrap-secrets = lib.mkIf (builtins.pathExists masterAgePath) {
          description = "angst: set login password hash from secrets";
          wantedBy = [ "multi-user.target" ];
          before = [
            "getty@.service"
            "serial-getty@.service"
            "display-manager.service"
          ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart =
              (runtime.bootstrap-secrets {
                inherit (host) username;
                agePath = masterAgePath;
                ageKey = "/home/${host.username}/.config/age/keys.txt";
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
            db
            sshAgent
            ssh
            ftp
            shell
            projects
            ;
          hostType = host.type;
          hostScopes = host.scopes;
          hostSecrets = host.secrets;
          hostName = host.hostname;
          inherit (host.scan) themes;
          themesLib = host.scan.themes;
          userConfig = userCfg;
          theme = effectiveTheme;
          flakeSelf = self;
          inherit inputs runtime store;
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
      systemd.services."home-manager-${host.username}".before = lib.optionals (!config.angst.isQemuVm) [
        "getty@.service"
        "serial-getty@.service"
      ];
    })
  ];
}
