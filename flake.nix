{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    vm = {
      url = "./tools/vm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    shell = {
      url = "./tools/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      themesLib = import ./themes/default.nix { inherit lib; };
      resolve = import ./lib/resolve.nix;

      discoverHosts = import ./lib/discover.nix { inherit lib; };
      hostEntries = discoverHosts ./hosts;

      mkHost =
        { domain, dir }:
        let
          hostDecl = import (./hosts + "/${dir}");
        in
        (resolve {
          inherit inputs themesLib domain;
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
