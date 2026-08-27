{
  inputs,
  themesLib,
  domain,
  decl,
  self ? null,
  pkgsOverride ? null,
  tcIndexOverride ? null,
  domainsLibOverride ? null,
}:

let
  lib = inputs.nixpkgs.lib;

  system = decl.system or "x86_64-linux";
  pkgs =
    if pkgsOverride != null then
      pkgsOverride
    else
      import inputs.nixpkgs {
        inherit system;
        config = import ./nixpkgs-config.nix;
      };

  _toolchainDir = ../toolchains;
  _rawFiles = builtins.attrNames (
    lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix") (
      builtins.readDir _toolchainDir
    )
  );
  _tcIndex =
    if tcIndexOverride != null then
      tcIndexOverride
    else
      lib.listToAttrs (
        map (
          f:
          let
            name = lib.removeSuffix ".nix" f;
          in
          {
            inherit name;
            value = import (_toolchainDir + "/${f}") { inherit lib pkgs; };
          }
        ) _rawFiles
      );
  _allTCs = builtins.attrValues _tcIndex;

  domainsScan =
    if domainsLibOverride != null then
      null
    else
      import ./domains/scan.nix {
        inherit lib pkgs;
        domainsPath = if self != null then self + "/domains" else ../domains;
      };
  domainsModule = import ./domains/module.nix { };
  domainsLib =
    if domainsLibOverride != null then domainsLibOverride else domainsScan // domainsModule;

  _toolchains = decl.toolchains or "*";
  _bareNames = builtins.attrNames _tcIndex;
  _selectedTCs =
    if _toolchains == "*" then
      _allTCs
    else if builtins.isList _toolchains then
      let
        unknown = builtins.filter (n: !builtins.elem n _bareNames) _toolchains;
      in
      if unknown != [ ] then
        throw "Unknown toolchains: ${builtins.concatStringsSep ", " unknown}. Valid: ${builtins.concatStringsSep ", " _bareNames}"
      else
        map (n: _tcIndex.${n}) _toolchains
    else
      throw "toolchains must be \"*\" or a list";
in

{
  inherit _tcIndex _allTCs _selectedTCs;

  host = {
    inherit system pkgs;
    hostname = decl.hostname or "nixos";
    username = decl.username or "user";
    theme = decl.theme or "monochrome";

    password =
      decl.password
        or "$6$7BqkEtUqOq/ylZb5$0dij1Cb/ykQJ8Vqt7SEJ7MMD77gn/ZW0LuLGo6tjU4e3rQcIyoH7q878EU2xXB9Suwh2bV/d/kpWeVl/nbsoe.";
    monitors = decl.monitors or { };
    db = decl.db or { };
    profiles = decl.profiles or [ "base" ];
    toolchains = _toolchains;
    extraNixos = decl.nixos or { };
    extraHome = decl.home or { };
    env = decl.env or { };
    sshAgent = decl.sshAgent or { };
    ssh = decl.ssh or { };
    ftp = decl.ftp or { };
    shell = decl.shell or "";
    persist = {
      root = "/persist";
      homeDirs = [ ];
      enable = false;
    }
    // (decl.persist or { });
    projects = decl.projects or [ ];
    type = decl.type or "nixos";
    inherit domain;

    scopes =
      let
        inWork = domain == "work";
        inPersonal = domain == "personal";
        isVm = (decl.hostname or "nixos") == "vm";
      in
      if inWork then
        [ "work" ]
      else if inPersonal then
        [
          "personal"
          "work"
        ]
      else if isVm then
        [
          "personal"
          "work"
        ]
      else
        [ "work" ];

    secrets = decl.secrets or [ ];

    toolchainModules = _selectedTCs;

    scan = {
      domains = domainsLib;
      themes = themesLib;
      allToolchainPackages = lib.unique (lib.concatMap (t: t.home.packages or [ ]) _selectedTCs);
      treesitter = import ./treesitter.nix {
        inherit lib pkgs;
        grammars = lib.unique (lib.concatMap (t: t.toolchains.treesitterGrammars or [ ]) _selectedTCs);
      };
    };
  };
}
