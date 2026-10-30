{
  inputs,
  self,
  host,
  hmModules,
  angstShell,
  runtime,
  hmSwitchTool,
  themeOverride ? null,
  shellOverride ? null,
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
  themeNames = lib.attrNames host.scan.themes.themes;
  isDesktop = builtins.elem "desktop" host.profiles;
  userCfg = {
    inherit (host) username;
    homeDirectory = "/home/${host.username}";
  };

  appHomeModules = map host.scan.domains.mkDomainModule host.scan.domains.homeEntries;

  secrets = import ../../modules/secrets.nix {
    inherit
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
    hostType = host.type;
    hostScopes = host.scopes;
    hostSecrets = host.secrets;
    inherit host;
    shell = if shellOverride != null then shellOverride else host.shell;
    inherit (host.scan) themes;
    themeSys = host.scan.themes;
    hostName = host.hostname;
    userConfig = userCfg;
    inherit isDesktop themeNames;
    theme = effectiveTheme;
    themeDefault = effectiveTheme;
    flakeSelf = self;
    inherit inputs runtime store;
  };

  modules = [
    ../../modules/home
  ]
  ++ host.scan.themes.homeModules
  ++ appHomeModules
  ++ hmModules
  ++ host.toolchainModules
  ++ secrets.homeModules
  ++ [
    (_: {
      home.packages = lib.optionals (builtins.elem "vm" host.profiles) [ runtime.vmTool ] ++ [
        angstShell
        runtime.angst-cli
        hmSwitchTool
      ];
    })
  ]
  ++ (if host.extraHome != { } then [ host.extraHome ] else [ ])
  ++ (if host.env != { } then [ { home.sessionVariables = host.env; } ] else [ ]);
}
