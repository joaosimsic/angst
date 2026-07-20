{
  inputs,
  self,
  cfg,
  hmModules,
  vmTool,
  shellTool,
  angstTool,
  themeOverride ? null,
}:

let
  pkgs = import inputs.nixpkgs {
    system = cfg.system;
    config = import ./nixpkgs-config.nix;
  };
  lib = pkgs.lib;

  effectiveTheme = if themeOverride != null then themeOverride else cfg.theme;
  userCfg = {
    username = cfg.username;
    homeDirectory = "/home/${cfg.username}";
  };

  appHomeModules = map cfg.scan.domains.mkDomainModule cfg.scan.domains.homeEntries;

  themeModule = import ./home/themeModule.nix {
    inherit lib;
    themesLib = cfg.scan.themes;
    hostTheme = effectiveTheme;
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = pkgs;

  extraSpecialArgs = {
    inherit (cfg) hostname monitors repoPath;
    inherit (cfg.scan) themes;
    themesLib = cfg.scan.themes;
    hostName = cfg.hostname;
    userConfig = userCfg;
    theme = effectiveTheme;
    flakeSelf = self;
  };

  modules = [
    ./home
  ]
  ++ [
    themeModule
    ./home/i3Fragments.nix
  ]
  ++ appHomeModules
  ++ hmModules
  ++ cfg.toolchainModules
  ++ [
    ({ ... }: {
      home.packages = [
        vmTool
        shellTool
        angstTool
      ];
    })
  ]
  ++ (if cfg.extraHome != { } then [ cfg.extraHome ] else [ ]);
}
