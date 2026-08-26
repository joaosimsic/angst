{
  self,
  inputs,
  hostDefs,
  themesLib,
}:

let
  inherit (inputs.nixpkgs) lib;

  hostList = builtins.attrValues hostDefs;
  nixosHosts = builtins.filter (h: h.type == "nixos") hostList;
  representative =
    if nixosHosts != [ ] then
      builtins.head nixosHosts
    else if hostList != [ ] then
      builtins.head hostList
    else
      null;
  defaultSystem = if representative != null then representative.system else "x86_64-linux";

  pkgs =
    if representative != null && representative ? pkgs then
      representative.pkgs
    else
      import inputs.nixpkgs {
        system = defaultSystem;
        config = import ../nixpkgs-config.nix;
      };

  profilesFor =
    host:
    import ../../profiles/default.nix {
      inherit (host) profiles scan;
      inherit lib;
    };

  enableModule = e: {
    domains.${e.category}.${e.name}.enable = true;
  };

  mkHome = import ../build/mkHome.nix;
  mkHost = import ../build/mkNixos.nix;

  runtime = import ../../runtime {
    inherit
      pkgs
      lib
      self
      ;
  };

  inherit (runtime) hmSwitchTool;

  fallbackHost = {
    scan = {
      domains.homeEntries = [ ];
      themes = themesLib;
    };
    monitors = { };
    db = { };
    sshAgent = { };
    username = "user";
  };

  render = import ../render.nix {
    host = if representative != null then representative else fallbackHost;
    inherit lib;
  };

  mkHomeCfg =
    {
      host,
      hmModules,
      themeOverride ? null,
      shellOverride ? null,
    }:
    mkHome {
      inherit
        self
        inputs
        host
        runtime
        hmSwitchTool
        angstShell
        hmModules
        themeOverride
        shellOverride
        ;
    };

  mkHostFor =
    host:
    let
      p = profilesFor host;
    in
    mkHost {
      inherit
        self
        inputs
        host
        runtime
        ;
      hmModules = map enableModule p.enabled;
      nixosModules = map enableModule (builtins.filter (e: e.hasSystem) p.enabled) ++ p.modules;
    };

  devshell = import ./devshell.nix {
    inherit
      pkgs
      runtime
      ;
    host = representative;
  };

  angstShell = runtime.mkAngstShell {
    devShell = devshell.shells.dev;
    safeShell = devshell.shells.safe;
    treesitter = if representative != null then representative.scan.treesitter else null;
  };

  mkChecks = import ../../checks/default.nix {
    inherit
      self
      pkgs
      lib
      render
      hostList
      runtime
      ;
    host = representative;
  };

  representativeHomes =
    if representative != null then
      let
        r = representative;
        p = profilesFor r;
        overrideTheme = builtins.head (
          builtins.filter (n: n != r.theme) (builtins.attrNames r.scan.themes.themes)
        );
      in
      {
        "${r.username}" = mkHomeCfg {
          host = r;
          hmModules = map enableModule p.enabled;
        };

        "${r.username}-theme-override-test" = mkHomeCfg {
          host = r;
          hmModules = map enableModule p.enabled;
          themeOverride = overrideTheme;
          shellOverride = "";
        };

        login-shell-valid = mkHomeCfg {
          host = r;
          hmModules = map enableModule p.enabled;
          shellOverride = "sh";
        };

        login-shell-invalid = mkHomeCfg {
          host = r;
          hmModules = map enableModule p.enabled;
          shellOverride = "__angst_nonexistent_shell__";
        };
      }
    else
      { };

  nixosConfigurations = builtins.listToAttrs (
    map (host: {
      name = host.hostname;
      value = mkHostFor host;
    }) nixosHosts
  );

  homeConfigurations =
    builtins.listToAttrs (
      map (host: {
        name = host.hostname;
        value = mkHomeCfg {
          inherit host;
          hmModules = map enableModule (profilesFor host).enabled;
        };
      }) hostList
    )
    // representativeHomes;
in
{
  inherit
    self
    inputs
    hostDefs
    themesLib
    lib
    hostList
    nixosHosts
    representative
    defaultSystem
    pkgs
    profilesFor
    enableModule
    runtime
    hmSwitchTool
    angstShell
    render
    mkHomeCfg
    mkHostFor
    devshell
    mkChecks
    nixosConfigurations
    homeConfigurations
    ;
}
