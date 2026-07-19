{ inputs, self, cfg, hmModules, nixosModules, themeOverride ? null }:

let
  pkgs = import inputs.nixpkgs { system = cfg.system; config.allowUnfree = true; };
  lib = pkgs.lib;

  effectiveTheme = if themeOverride != null then themeOverride else cfg.theme;
  userCfg = { username = cfg.username; homeDirectory = "/home/${cfg.username}"; };

  appNixosModules = map cfg.scan.domains.mkNixosDomainModule cfg.scan.domains.nixosEntries;
  appHomeModules  = map cfg.scan.domains.mkDomainModule cfg.scan.domains.homeEntries;

  themeModule = import ../home/themeModule.nix {
    inherit lib; themesLib = cfg.scan.themes; hostTheme = effectiveTheme;
  };

  hardwarePath =
    let
      fromEnv = let r = builtins.getEnv "ANGST_REPO"; in
        if r != "" then r + "/local/hardware.nix" else "";
      fromPwd = let p = builtins.getEnv "PWD"; in
        if p != "" then p + "/local/hardware.nix" else "";
      fromHome = let h = builtins.getEnv "HOME"; in
        if h != "" then h + "/proj/angst/local/hardware.nix" else "";
      fromHost9p = let h = builtins.getEnv "HOME"; in
        if h != "" then "/host${h}/proj/angst/local/hardware.nix" else "";
      candidates = lib.filter (p: p != "" && builtins.pathExists p) [ fromEnv fromPwd fromHome fromHost9p ];
    in
    if candidates != [] then builtins.head candidates else null;
in
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = {
    inherit (cfg) hostname monitors repoPath;
    inherit (cfg.scan) themes;
    themesLib = cfg.scan.themes;
    hostName = cfg.hostname;
    flakeSelf = self;
    userConfig = userCfg;
    theme = effectiveTheme;
  };

  modules =
    [ { nixpkgs.hostPlatform = cfg.system; } ]
    ++ nixosModules
    ++ appNixosModules
    ++ [ ../../lib/nixos ]
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
            inherit (cfg.scan) themes;
            themesLib = cfg.scan.themes;
            hostName = cfg.hostname;
            flakeSelf = self;
            userConfig = userCfg;
            theme = effectiveTheme;
          };

          users.${cfg.username} = {
            imports =
              [ ../../lib/home ]
              ++ [ themeModule ../../lib/home/i3Fragments.nix ]
              ++ appHomeModules     # domain modules (so enable options exist)
              ++ hmModules          # profile enable modules
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
