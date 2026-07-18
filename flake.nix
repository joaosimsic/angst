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

  outputs = { self, nixpkgs, home-manager, vm, shell, ... }@inputs:
    let
      pure  = import ./lib/read-config.nix { inherit inputs self; };
      cfg   = pure.cfg;
      pkgs  = import nixpkgs { system = cfg.system; config.allowUnfree = true; };
      profiles = import ./lib/profiles.nix {
        inherit (cfg) profiles;
        lib = pkgs.lib;
        scan = cfg.scan;
      };
    in
    import ./lib/outputs.nix { inherit self inputs cfg profiles; };
}
