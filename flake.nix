{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      themesLib = import ./themes/default.nix { inherit lib; };
      resolve = import ./lib/resolve.nix;

      discoverHosts = import ./lib/discover.nix { inherit lib; };
      hostEntries = discoverHosts ./hosts;

      pkgsFor = system: import nixpkgs { inherit system; config = import ./lib/nixpkgs-config.nix; };
      sharedPkgs = pkgsFor "x86_64-linux";

      _sharedRawFiles = builtins.attrNames (
        lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix") (
          builtins.readDir ./toolchains
        )
      );
      sharedTcIndex = lib.listToAttrs (
        map (
          f:
          let
            name = lib.removeSuffix ".nix" f;
          in
          {
            inherit name;
            value = import (./toolchains + "/${f}") { inherit lib; pkgs = sharedPkgs; };
          }
        ) _sharedRawFiles
      );
      sharedDomainsLib =
        (import ./lib/domains/scan.nix {
          inherit lib;
          pkgs = sharedPkgs;
          domainsPath = ./domains;
        } // import ./lib/domains/module.nix { });

      mkHost =
        { domain, dir }:
        let
          hostDecl = import (./hosts + "/${dir}");
          system = hostDecl.system or "x86_64-linux";
          pkgs = if system == "x86_64-linux" then sharedPkgs else pkgsFor system;
          tcIndexOverride = if system == "x86_64-linux" then sharedTcIndex else null;
          domainsLibOverride = if system == "x86_64-linux" then sharedDomainsLib else null;
        in
        (resolve {
          inherit inputs themesLib domain tcIndexOverride domainsLibOverride;
          pkgsOverride = pkgs;
          decl = hostDecl;
        }).host;

      hostDefs = builtins.listToAttrs (
        map (h: {
          name = h.hostname;
          value = mkHost { inherit (h) domain dir; };
        }) hostEntries
      );
    in
    import ./lib/flake/outputs.nix {
      inherit
        self
        inputs
        hostDefs
        themesLib
        ;
    };
}
