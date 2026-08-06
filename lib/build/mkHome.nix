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
  ++ [
    (_: {
      home.packages = [
        vmTool
        shellTool
        angstTool
      ];
    })
  ]
  ++ (if cfg.extraHome != { } then [ cfg.extraHome ] else [ ])
  ++ (if cfg.env != { } then [ { home.sessionVariables = cfg.env; } ] else [ ]);
}
