{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
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
      readConfig = import ./lib/read-config.nix;

      hostDirs = builtins.attrNames (
        lib.filterAttrs (_: t: t == "directory") (builtins.readDir ./hosts)
      );

      mkCfg =
        hostname:
        let
          rawConfig = import (./hosts + "/${hostname}");
        in
        (readConfig { inherit inputs themesLib; config = rawConfig; }).cfg;

      hostCfgs = lib.listToAttrs (map (h: { name = h; value = mkCfg h; }) hostDirs);
    in
    import ./lib/flake/outputs.nix {
      inherit
        self
        inputs
        hostCfgs
        themesLib
        ;
    };
}
