{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vm-cli = {
      url = "path:./tools/vm-cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, vm-cli, ... }@inputs:
  let
    hosts = import ./lib/build/scanHosts.nix inputs;

    env = {
      inherit inputs;

      flakeSelf = self;

      loadHost = hostname: import (./hosts + "/${hostname}");
    };

    homeLib = import ./lib/build/mkHome.nix env;
    mkHost = import ./lib/build/mkHost.nix (env // {
      mkHomeProfile = homeLib.mkHomeProfile;
      flakeSelf = self;
    });
    inherit (homeLib) mkHome mkHomeWithExtraModules;

    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    flakeLib = import ./lib/flake/default.nix {
      inherit self system pkgs hosts mkHome mkHomeWithExtraModules vm-cli;
      loadHost = env.loadHost;
      lib = pkgs.lib;
    };
  in
  {
    inherit (flakeLib) themeLint lintDesktop lintShell themeRenderedChecks renderTemplateFor;

    nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost;

    inherit (flakeLib) homeConfigurations checks packages apps;
  };
}
