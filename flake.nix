{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      themesLib = import ./themes/default.nix { lib = inputs.nixpkgs.lib; };
      pure = import ./lib/read-config.nix { inherit inputs themesLib; };
      inherit (pure) cfg;
      pkgs = import nixpkgs {
        inherit (cfg) system;
        config = import ./lib/nixpkgs-config.nix;
      };
      profiles = import ./profiles/default.nix {
        inherit (cfg) profiles;
        inherit (pkgs) lib;
        inherit (cfg) scan;
      };
    in
    import ./lib/flake/outputs.nix {
      inherit
        self
        inputs
        cfg
        profiles
        ;
    };
}
