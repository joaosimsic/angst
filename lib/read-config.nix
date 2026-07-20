{
  inputs,
  themesLib,
}:

let
  lib = inputs.nixpkgs.lib;

  config =
    let
      pwd = builtins.getEnv "PWD";
      absPath = pwd + "/local/config.nix";
    in
    if pwd != "" && builtins.pathExists absPath then import absPath else { };
  system = config.system or "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config = import ./nixpkgs-config.nix;
  };

  _toolchainDir = ../toolchains;
  _rawFiles = builtins.attrNames (
    lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix") (
      builtins.readDir _toolchainDir
    )
  );
  _tcIndex = lib.listToAttrs (
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

  domainsScan = import ./domains/scan.nix {
    inherit lib;
    domainsPath = ../domains;
  };
  domainsModule = import ./domains/module.nix {
    mkDomainActivation = (import ./activation.nix).mkDomainActivation;
  };
  domainsLib = domainsScan // domainsModule;

  _toolchains = config.toolchains or "*";
  _bareNames = builtins.attrNames _tcIndex;
in

{
  inherit _tcIndex _allTCs;

  cfg = {
    system = system;
    hostname = config.hostname or "nixos";
    username = config.username or "user";
    theme = config.theme or "monochrome";
    password = config.password or "!";
    monitors = config.monitors or { };
    profiles = config.profiles or [ "base" ];
    toolchains = _toolchains;
    repoPath = config.repoPath or "proj/angst";
    extraNixos = config.nixos or { };
    extraHome = config.home or { };

    scan = {
      domains = domainsLib;
      themes = themesLib;
      allToolchainPackages = lib.unique (lib.concatMap (t: t.home.packages or [ ]) _allTCs);
      treesitter = import ../lib/treesitter.nix {
        inherit lib pkgs;
        grammars = lib.unique (lib.concatMap (t: t.toolchains.treesitterGrammars or [ ]) _allTCs);
      };
    };

    toolchainModules =
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
  };
}
