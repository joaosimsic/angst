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

  pkgs = import inputs.nixpkgs {
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

  vmOutputs = inputs.vm.mkOutputs self;
  shellOutputs = inputs.shell.mkOutputs self;
  vmTool = vmOutputs.packages.${defaultSystem}.default or vmOutputs.packages.${defaultSystem}.vm;
  shellTool = shellOutputs.packages.${defaultSystem}.default;

  runtime = import ../../runtime {
    inherit
      pkgs
      lib
      self
      ;
  };

  hmSwitchTool = runtime.hmSwitchTool;

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
        vmTool
        shellTool
        runtime
        hmSwitchTool
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
      inputs
      vmOutputs
      runtime
      ;
    host = representative;
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
    vmOutputs
    shellOutputs
    vmTool
    shellTool
    runtime
    hmSwitchTool
    render
    mkHomeCfg
    mkHostFor
    devshell
    mkChecks
    nixosConfigurations
    homeConfigurations
    ;
}
