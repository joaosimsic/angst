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
    {
      self,
      nixpkgs,
      vm,
      shell,
      ...
    }@inputs:
    let
      hosts = import ./lib/build/scanHosts.nix inputs;

      env = {
        inherit inputs;

        flakeSelf = self;

        loadHost = hostname: import (./hosts + "/${hostname}");
      };

      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      vmOutputs = vm.mkOutputs self;
      shellOutputs = shell.mkOutputs self;

      shared = import ./lib/flake/shared.nix {
        inherit pkgs shellOutputs vmOutputs system;
        lib = pkgs.lib;
      };

      homeLib = import ./lib/build/mkHome.nix (
        env
        // {
          vmTool = vmOutputs.packages.${system}.default;
          shellTool = shared.shellTool;
        }
      );

      mkHost = import ./lib/build/mkHost.nix (
        env
        // {
          inherit (homeLib) mkHomeProfile;
          flakeSelf = self;
        }
      );

      inherit (homeLib) mkHome mkHomeWithExtraModules;

      flakeLib = import ./lib/flake/default.nix {
        inherit
          self
          system
          pkgs
          hosts
          mkHome
          mkHomeWithExtraModules
          ;
        inherit vmOutputs shellOutputs;
        inherit (env) loadHost;
        inherit (pkgs) lib;
      };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs
        (builtins.filter (h: builtins.pathExists (./hosts + "/${h}/configuration.nix")) hosts)
        mkHost;

      inherit (flakeLib)
        homeConfigurations
        checks
        packages
        apps
        devShells
        ;

      formatter.${system} = pkgs.nixfmt;

      lib = {
        inherit (flakeLib)
          themeLint
          renderDomainOutputsFor
          renderDomainOutputPathsFor
          renderDomainOutputFor
          ;
      };
    };
}
