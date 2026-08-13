{
  inputs,
  self,
  host,
  hmModules,
  vmTool,
  shellTool,
  runtime,
  resTool,
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

  secrets = import ../../modules/secrets.nix {
    inherit
      inputs
      self
      host
      lib
      ;
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit (host)
      hostname
      monitors
      db
      sshAgent
      ssh
      ftp
      projects
      ;
    shell = if shellOverride != null then shellOverride else host.shell;
    inherit (host.scan) themes;
    themesLib = host.scan.themes;
    hostName = host.hostname;
    userConfig = userCfg;
    theme = effectiveTheme;
    flakeSelf = self;
    inherit runtime;
  };

  modules = [
    ../../modules/home
    themeModule
  ]
  ++ appHomeModules
  ++ hmModules
  ++ host.toolchainModules
  ++ secrets.homeModules
  ++ [
    (_: {
      home.packages = [
        vmTool
        shellTool
        runtime.angstCli
        resTool
      ];
    })
  ]
  ++ (if host.extraHome != { } then [ host.extraHome ] else [ ])
  ++ (if host.env != { } then [ { home.sessionVariables = host.env; } ] else [ ]);
}
