{ inputs, self, cfg, hmModules, nixosModules, themeOverride ? null }:

let
  pkgs = import inputs.nixpkgs { system = cfg.system; config = import ./nixpkgs-config.nix; };
  lib = pkgs.lib;

  effectiveTheme = if themeOverride != null then themeOverride else cfg.theme;
  userCfg = { username = cfg.username; homeDirectory = "/home/${cfg.username}"; };

  appNixosModules = map cfg.scan.domains.mkNixosDomainModule cfg.scan.domains.nixosEntries;
  appHomeModules  = map cfg.scan.domains.mkDomainModule cfg.scan.domains.homeEntries;

  themeModule = import ./home/themeModule.nix {
    inherit lib; themesLib = cfg.scan.themes; hostTheme = effectiveTheme;
  };

  hardwarePath =
    let p = "${toString self}/local/hardware.nix";
    in if builtins.pathExists p then p else null;
in
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = {
    inherit (cfg) hostname monitors repoPath;
    hostName = cfg.hostname;
    inherit (cfg.scan) themes;
    themesLib = cfg.scan.themes;
    userConfig = userCfg;
    theme = effectiveTheme;
    flakeSelf = self;
  };

  modules =
    [ { nixpkgs.hostPlatform = cfg.system; } ]
    ++ nixosModules
    ++ appNixosModules
    ++ [ ./nixos ]
    ++ (if hardwarePath != null then [ (import hardwarePath) ] else [])
    ++ (if cfg.extraNixos != {} then [ cfg.extraNixos ] else [])
    ++ [
      ({ lib, ... }: {
        users.users.${cfg.username}.hashedPassword = lib.mkDefault cfg.password;
      })

      inputs.home-manager.nixosModules.home-manager {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "hm-backup";

          extraSpecialArgs = {
            inherit (cfg) hostname monitors repoPath;
            hostName = cfg.hostname;
            inherit (cfg.scan) themes;
            themesLib = cfg.scan.themes;
            userConfig = userCfg;
            theme = effectiveTheme;
            flakeSelf = self;
          };

          users.${cfg.username} = {
            imports =
              [ ./home ]
              ++ [ themeModule ./home/i3Fragments.nix ]
              ++ appHomeModules
              ++ hmModules
              ++ cfg.toolchainModules;
          };
        };
      }

      ({ config, lib, ... }: {
        systemd.services."home-manager-${cfg.username}".before =
          lib.mkIf (!config.angst.isQemuVm) [
            "getty@.service" "serial-getty@.service"
          ];
      })
    ];
}
