{ inputs, self }:

let
  lib = inputs.nixpkgs.lib;

  # Resolve local/config.nix from the real filesystem (gitignored, not in Nix store)
  configPath =
    let
      fromEnv = let r = builtins.getEnv "ANGST_REPO"; in
        if r != "" then r + "/local/config.nix" else "";
      fromPwd = let p = builtins.getEnv "PWD"; in
        if p != "" then p + "/local/config.nix" else "";
      fromHome = let h = builtins.getEnv "HOME"; in
        if h != "" then h + "/proj/angst/local/config.nix" else "";
      fromHost9p = let h = builtins.getEnv "HOME"; in
        if h != "" then "/host${h}/proj/angst/local/config.nix" else "";
      fromExample = let p = builtins.getEnv "PWD"; in
        if p != "" then p + "/local/config.nix.example" else "";
      candidates = lib.filter (p: p != "" && builtins.pathExists p) [ fromEnv fromPwd fromHome fromHost9p fromExample ];
    in
    if candidates != [] then builtins.head candidates
    else builtins.throw ''
      local/config.nix not found.

      Create it by copying the template:
        cp local/config.nix.example local/config.nix
        # then edit local/config.nix with your settings

      Or set ANGST_REPO to the repo root path.
    '';

  config = import configPath;
  system = config.system or "x86_64-linux";
  pkgs = import inputs.nixpkgs { inherit system; config.allowUnfree = true; };

  # Toolchain evaluation — once, indexed by bare name
  _toolchainDir = ../toolchains;
  _rawFiles = builtins.attrNames (
    lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix")
      (builtins.readDir _toolchainDir)
  );
  _tcIndex = lib.listToAttrs (map (f:
    let name = lib.removeSuffix ".nix" f;
    in { inherit name; value = import (_toolchainDir + "/${f}") { inherit lib pkgs; }; }
  ) _rawFiles);
  _allTCs = builtins.attrValues _tcIndex;

  domainsLib = import ../lib/domains/default.nix { inherit lib; domainsPath = ../domains; };
  themesLib  = import ../themes/default.nix { inherit lib; };
in

# Helpers exported alongside cfg (used by lib/profiles.nix)
{
  inherit _tcIndex _allTCs;

  cfg = {
    system     = system;
    hostname   = config.hostname;
    username   = config.username;
    theme      = config.theme or "monochrome";
    password   = config.password;
    monitors   = config.monitors or {};
    profiles   = config.profiles or [ "base" ];
    toolchains = config.toolchains or "*";
    repoPath   = config.repoPath;
    extraNixos = config.nixos or {};
    extraHome  = config.home or {};

    # resolved from scan (evaluated once here, not by builders)
    scan = {
      domains = domainsLib;
      themes = themesLib;
      allToolchainPackages = lib.unique (lib.concatMap (t: t.home.packages or []) _allTCs);
      treesitter = import ../lib/treesitter.nix {
        inherit lib pkgs;
        grammars = lib.unique (lib.concatMap (t: t.toolchains.treesitterGrammars or []) _allTCs);
      };
    };

    # toolchain modules — shares _tcIndex with scan (no re-import)
    toolchainModules =
      let bareNames = builtins.attrNames _tcIndex;
      in if config.toolchains == "*" then _allTCs
         else if builtins.isList config.toolchains then
           let unknown = builtins.filter (n: !builtins.elem n bareNames) config.toolchains;
           in if unknown != []
             then builtins.throw "Unknown toolchains: ${builtins.concatStringsSep ", " unknown}. Valid: ${builtins.concatStringsSep ", " bareNames}"
             else map (n: _tcIndex.${n}) config.toolchains
         else builtins.throw "toolchains must be \"*\" or a list";
  };
}
